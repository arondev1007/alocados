// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/*
    SubscriptionNFT
        - ERC721 기반 구독권 컨트랙트
        - 사업자 중심 기반 과금 모델
*/

interface IPaymentTokenPermitTransfer {
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

contract SubscriptionNFT is ERC721, Ownable {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    // 구독 데이터
    struct Subscription {
        address payer;
        uint64 startTime;
        uint64 endTime;
        uint64 lastClaimTime;
        uint256 monthlyPrice;
        bool active;
    }

    uint256 private _tokenSeq;
    mapping(uint256 => Subscription) private _subs;

    IPaymentTokenPermitTransfer public paymentToken;

    // 이벤트 정의
    event Subscribed(uint256 indexed tokenId, address payer);
    event Unsubscribed(uint256 indexed tokenId);
    event Assigned(uint256 indexed tokenId, address from, address to);
    event Claimed(uint256 indexed tokenId, bool success);

    // 오류 정의
    error InvalidSignature();
    error Unauthorized();
    error InvalidState();

    // 청구할 ERC-20 토큰 컨트랙트를 설정
    constructor(
        address token
    ) ERC721("SubscriptionNFT", "SUBNFT") Ownable(msg.sender) {
        paymentToken = IPaymentTokenPermitTransfer(token);
    }

    // ERC20 설정
    function setPaymentToken(address token) external onlyOwner {
        paymentToken = IPaymentTokenPermitTransfer(token);
    }

    // 구독 ( 사업자 )
    function subscribe(
        address subscriber,
        uint256 price,
        uint64 start,
        uint64 end,
        bytes calldata signature
    ) external onlyOwner {
        _verifySubscribeSig(subscriber, price, start, end, signature);

        uint256 tokenId = ++_tokenSeq;
        _mint(subscriber, tokenId);

        _subs[tokenId] = Subscription({
            payer: subscriber,
            startTime: start,
            endTime: end,
            lastClaimTime: start,
            monthlyPrice: price,
            active: true
        });

        emit Subscribed(tokenId, subscriber);
    }

    // 구독 해지
    function unsubscribe(uint256 tokenId) external {
        Subscription storage s = _subs[tokenId];

        if (msg.sender != ownerOf(tokenId) && msg.sender != s.payer)
            revert Unauthorized();

        s.active = false;
        _transfer(ownerOf(tokenId), address(this), tokenId);

        emit Unsubscribed(tokenId);
    }

    // 구독권 양도
    function assign(
        uint256 tokenId,
        address from,
        address to,
        bytes calldata sigFrom,
        bytes calldata sigTo
    ) external onlyOwner {
        _verifyAssignSig(tokenId, from, sigFrom);
        _verifyAssignSig(tokenId, to, sigTo);

        _subs[tokenId].payer = to;

        emit Assigned(tokenId, from, to);
    }

    // 청구 ( 사업자 )
    function claim(uint256 tokenId) external onlyOwner {
        Subscription storage s = _subs[tokenId];

        if (!s.active) {
            emit Claimed(tokenId, false);
            return;
        }

        if (block.timestamp < s.lastClaimTime + 30 days) {
            emit Claimed(tokenId, false);
            return;
        }

        try
            paymentToken.transferFrom(s.payer, owner(), s.monthlyPrice)
        returns (bool ok) {
            if (ok) {
                s.lastClaimTime += 30 days;
                emit Claimed(tokenId, true);
                return;
            }
        } catch {}

        // 결제 실패 -> 구독 중단 + NFT 회수
        s.active = false;
        _transfer(ownerOf(tokenId), address(this), tokenId);
        emit Claimed(tokenId, false);
    }

    // 구독자 전용 함수
    function ping(bytes calldata data) external view returns (bytes memory) {
        if (balanceOf(msg.sender) == 0) revert Unauthorized();
        return data;
    }

    function _verifySubscribeSig(
        address user,
        uint256 price,
        uint64 start,
        uint64 end,
        bytes calldata sig
    ) internal view {
        bytes32 hash = keccak256(
            abi.encodePacked(user, price, start, end, address(this))
        ).toEthSignedMessageHash();

        if (hash.recover(sig) != user) revert InvalidSignature();
    }

    function _verifyAssignSig(
        uint256 tokenId,
        address signer,
        bytes calldata sig
    ) internal view {
        bytes32 hash = keccak256(
            abi.encodePacked(tokenId, signer, address(this))
        ).toEthSignedMessageHash();

        if (hash.recover(sig) != signer) revert InvalidSignature();
    }
}

//SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "base64-sol/base64.sol";

library HexStrings {
    bytes16 internal constant ALPHABET = "0123456789abcdef";

    function toHexString(uint256 value, uint256 length)
        internal
        pure
        returns (string memory)
    {
        bytes memory buffer = new bytes(2 * length + 2);
        (buffer[0], buffer[1]) = ("0", "x");
        unchecked {
            for (uint256 i = 2 * length + 1; i > 1; --i) {
                buffer[i] = ALPHABET[value & 0xf];
                value >>= 4;
            }
        }
        return string(buffer);
    }
}

library ToColor {
    bytes16 internal constant ALPHABET = "0123456789abcdef";

    function toColor(bytes3 value) internal pure returns (string memory) {
        bytes memory buffer = new bytes(6);
        unchecked {
            for (uint256 i = 0; i < 3; ++i) {
                buffer[i * 2 + 1] = ALPHABET[uint8(value[i]) & 0xf];
                buffer[i * 2] = ALPHABET[uint8(value[i] >> 4) & 0xf];
            }
        }
        return string(buffer);
    }
}

contract YourCollectible is ERC721Enumerable {
    using Strings for uint256;
    using HexStrings for uint160;
    using ToColor for bytes3;
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    address payable public constant recipient =
        payable(0x2e0aCE0129E66A36cee92c5146C73Ec4874d0109);

    uint256 public constant limit = 3728;
    uint256 public constant curve = 1002;
    uint256 public price = 0.001 ether;

    mapping(uint256 => bytes3) public color;
    mapping(uint256 => uint256) public chubbiness;
    mapping(uint256 => uint256) public mouthLength;

    constructor() ERC721("OptimisticLoogies", "OPLOOG") {}

    function mintItem() public payable returns (uint256) {
        require(
            _tokenIds.current() < limit && msg.value >= price,
            "Mint: error"
        );

        _tokenIds.increment();

        uint256 id = _tokenIds.current();
        _mint(msg.sender, id);

        unchecked {
            bytes32 predictableRandom = keccak256(
                abi.encodePacked(
                    id,
                    blockhash(block.number - 1),
                    msg.sender,
                    address(this)
                )
            );
            color[id] =
                bytes2(predictableRandom[0]) |
                (bytes2(predictableRandom[1]) >> 8) |
                (bytes3(predictableRandom[2]) >> 16);
            chubbiness[id] =
                35 +
                ((55 * uint256(uint8(predictableRandom[3]))) / 255);
            mouthLength[id] =
                180 +
                ((uint256(chubbiness[id] / 4) *
                    uint256(uint8(predictableRandom[4]))) / 255);

            price = (price * curve) / 1000;
        }
        (bool success, ) = recipient.call{value: msg.value}("");
        require(success, "Mint: error");

        return id;
    }

    function tokenURI(uint256 id) public view override returns (string memory) {
        require(ownerOf(id) != address(0), "not exist");
        string memory name = string(
            abi.encodePacked("Loogie #", id.toString())
        );
        string memory description = string(
            abi.encodePacked(
                "This Loogie is the color #",
                color[id].toColor(),
                " with a chubbiness of ",
                uint2str(chubbiness[id]),
                " and mouth length of ",
                uint2str(mouthLength[id]),
                "!!!"
            )
        );
        string memory image = Base64.encode(bytes(generateSVGofTokenById(id)));

        return
            string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    Base64.encode(
                        bytes(
                            abi.encodePacked(
                                '{"name":"',
                                name,
                                '", "description":"',
                                description,
                                '", "external_url":"https://burnyboys.com/token/',
                                id.toString(),
                                '", "attributes": [{"trait_type": "color", "value": "#',
                                color[id].toColor(),
                                '"},{"trait_type": "chubbiness", "value": ',
                                uint2str(chubbiness[id]),
                                '},{"trait_type": "mouthLength", "value": ',
                                uint2str(mouthLength[id]),
                                '}], "owner":"',
                                (uint160(ownerOf(id))).toHexString(20),
                                '", "image": "',
                                "data:image/svg+xml;base64,",
                                image,
                                '"}'
                            )
                        )
                    )
                )
            );
    }

    function generateSVGofTokenById(uint256 id)
        internal
        view
        returns (string memory)
    {
        return
            string(
                abi.encodePacked(
                    '<svg width="400" height="400" xmlns="http://www.w3.org/2000/svg">',
                    renderTokenById(id),
                    "</svg>"
                )
            );
    }

    function renderTokenById(uint256 id) public view returns (string memory) {
        string memory render = string(
            abi.encodePacked(
                '<g id="eye1">',
                '<ellipse stroke-width="3" ry="29.5" rx="29.5" id="svg_1" cy="154.5" cx="181.5" stroke="#000" fill="#fff"/>',
                '<ellipse ry="3.5" rx="2.5" id="svg_3" cy="154.5" cx="173.5" stroke-width="3" stroke="#000" fill="#000"/>',
                "</g>",
                '<g id="head">',
                '<ellipse fill="#',
                color[id].toColor(),
                '" stroke-width="3" cx="204.5" cy="211.80065" id="svg_5" rx="',
                chubbiness[id].toString(),
                '" ry="51.80065" stroke="#000"/>',
                "</g>",
                '<g id="eye2">',
                '<ellipse stroke-width="3" ry="29.5" rx="29.5" id="svg_2" cy="168.5" cx="209.5" stroke="#000" fill="#fff"/>',
                '<ellipse ry="3.5" rx="3" id="svg_4" cy="169.5" cx="208" stroke-width="3" fill="#000" stroke="#000"/>',
                "</g>"
                '<g class="mouth" transform="translate(',
                uint256((810 - 9 * chubbiness[id]) / 11).toString(),
                ',0)">',
                '<path d="M 130 240 Q 165 250 ',
                mouthLength[id].toString(),
                ' 235" stroke="black" stroke-width="3" fill="transparent"/>',
                "</g>"
            )
        );

        return render;
    }

    function uint2str(uint256 _i)
        internal
        pure
        returns (string memory _uintAsString)
    {
        if (_i == 0) return "0";

        uint256 j = _i;
        uint256 len;
        unchecked {
            while (j != 0) {
                ++len;
                j /= 10;
            }
            bytes memory bstr = new bytes(len);
            uint256 k = len;
            while (_i != 0) {
                k = k - 1;
                uint8 temp = (48 + uint8(_i - (_i / 10) * 10));
                bytes1 b1 = bytes1(temp);
                bstr[k] = b1;
                _i /= 10;
            }
            return string(bstr);
        }
    }
}

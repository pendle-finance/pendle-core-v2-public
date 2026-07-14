// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.30;

import {Script} from "forge-std/src/Script.sol";
import {console} from "forge-std/src/console.sol";
import {StdConstants} from "forge-std/src/StdConstants.sol";
import {Vm} from "forge-std/src/Vm.sol";

/// @dev See https://eips.ethereum.org/EIPS/eip-712#definition-of-typed-structured-data-%F0%9D%95%8A
contract GenEIP712 is Script {
    mapping(string => bool) internal _isAtomicType;
    mapping(string => bool) internal _isAtomicArrayType;

    function _setAtomicType(string memory typeName) internal {
        _isAtomicType[typeName] = true;
        _isAtomicArrayType[string.concat(typeName, "[]")] = true;
    }

    function setUp() public {
        _setAtomicType("bool");
        _setAtomicType("address");
        for (uint256 i = 1; i <= 32; i++) {
            _setAtomicType(string.concat("bytes", vm.toString(i)));
            _setAtomicType(string.concat("int", vm.toString(i * 8)));
            _setAtomicType(string.concat("uint", vm.toString(i * 8)));
        }
    }

    /// @dev upper case field as the lowercase `type` is a keyword.
    struct Eip712Info {
        bytes32 Hash;
        string Path;
        string Type;
    }

    function getEip712Info(string memory filePath) public returns (Eip712Info[] memory) {
        string[] memory cmds = new string[](4);
        cmds[0] = "forge";
        cmds[1] = "eip712";
        cmds[2] = filePath;
        cmds[3] = "--json";

        bytes memory result = vm.ffi(cmds);
        return abi.decode(vm.parseJson(string(result)), (Eip712Info[]));
    }

    mapping(string => bool) internal isIndependentTypes;

    function run(
        string memory filePath,
        string memory interfaceName,
        string[] memory independentTypes,
        string memory outFile
    ) public {
        string memory joinedIndependentTypes = "";
        string memory joinedQuotedIndependentTypes = "";
        for (uint256 i = 0; i < independentTypes.length; ++i) {
            joinedQuotedIndependentTypes =
                string.concat(joinedQuotedIndependentTypes, i == 0 ? "" : ", ", '"', independentTypes[i], '"');
            joinedIndependentTypes = string.concat(joinedIndependentTypes, i == 0 ? "" : ", ", independentTypes[i]);
            isIndependentTypes[independentTypes[i]] = true;
        }
        console.log("Generating EIP712 info for : %s", filePath);
        console.log("Output file                : %s", outFile);
        console.log("Interface to generate      : %s", interfaceName);
        console.log("Indenendent types          : [%s]", joinedIndependentTypes);

        Eip712Info[] memory infos = getEip712Info(filePath);
        FileWriter memory out = FileWriterLib.from(outFile);

        out.write("// SPDX-License-Identifier: GPL-3.0-or-later");
        out.write("pragma solidity ^0.8.30;");
        out.write();
        out.write("////////// GENERATED FILE. DO NOT EDIT DIRECTLY.");
        out.write(
            string.concat(
                "// FOUNDRY_PROFILE=v2-script forge script script/GenEIP712.sol -- \"",
                filePath,
                "\" \"",
                interfaceName,
                "\" '[",
                joinedQuotedIndependentTypes,
                "]' \"",
                outFile,
                "\""
            )
        );
        out.write();
        if (independentTypes.length == 0) {
            out.write("import {", interfaceName, "} from \"", _relativePath(outFile, filePath), "\";");
        } else {
            out.write(
                string.concat(
                    "import {",
                    interfaceName,
                    ", ",
                    joinedIndependentTypes,
                    "} from \"",
                    _relativePath(outFile, filePath),
                    "\";"
                )
            );
        }
        out.write();
        out.write(
            "/// @notice Generate EIP712 `encodeData` function for types in ", interfaceName, " based on specification:"
        );
        out.write("/// https://eips.ethereum.org/EIPS/eip-712#definition-of-encodedata");
        out.write("// forgefmt: disable-next-item");
        out.startBlock("library ", _fileNameNoExt(outFile));

        bool isFirst = true;
        for (uint256 i = 0; i < infos.length; i++) {
            string[] memory pathParts = vm.split(infos[i].Path, " > ");
            string memory typeName;
            if (isIndependentTypes[infos[i].Path]) {
                typeName = infos[i].Path;
            } else if (pathParts.length == 3 && _eq(pathParts[1], interfaceName)) {
                typeName = string.concat(interfaceName, ".", pathParts[2]);
            } else {
                console.log("- %s: skip", infos[i].Path);
                continue;
            }

            console.log("+ %s: add", infos[i].Path);

            /// ========== Double check forge result here ==========
            require(keccak256(_asBytes(infos[i].Type)) == infos[i].Hash, "hash mismatch");

            if (isFirst) isFirst = false;
            else out.write();

            out.write("// ", infos[i].Path);

            out.startBlock("function encodeData(", typeName, " memory data) internal pure returns (bytes32)");

            string[] memory typePart = vm.split(infos[i].Type, ")"); // we will add ')' later when printing
            /// NOTICE that the last char ")" so typePart[typePart.length] is EMPTY
            {
                // output the raw computation for reader to verify by themselves
                out.write("/* bytes32 typeHash = keccak256(");
                out.indent++;
                for (uint256 typeI = 0; typeI + 1 < typePart.length; ++typeI) {
                    out.write("\"", typePart[typeI], ")\" ");
                }
                out.indent--;
                out.write("); */");
            }

            out.write("bytes32 typeHash = ", vm.toString(infos[i].Hash), ";");
            out.write("return keccak256(abi.encode(");
            out.indent++;
            out.write("typeHash,");

            string[] memory fields =
                vm.split(_subStr(typePart[0], vm.indexOf(typePart[0], "(") + 1, _length(typePart[0])), ",");

            for (uint256 j = 0; j < fields.length; j++) {
                string[] memory typeAndName = vm.split(fields[j], " ");
                string memory tp = typeAndName[0];
                string memory name = typeAndName[1];
                string memory commaSep = (j < fields.length - 1) ? "," : "";

                if (_eq(tp, "bytes")) {
                    out.write("keccak256(data.", name, ")", commaSep);
                } else if (_eq(tp, "string") || _isAtomicArrayType[tp]) {
                    out.write("keccak256(abi.encodePacked(data.", name, "))", commaSep);
                } else if (_isAtomicType[tp]) {
                    out.write("data.", name, commaSep);
                } else if (vm.contains(tp, "[")) {
                    revert(string.concat("non-atomic array type are not supported: ", tp));
                } else {
                    out.write("encodeData(data.", name, ")", commaSep);
                }
            }

            out.indent--;
            out.write("));");
            out.endBlock();
        }

        out.endBlock();
    }

    function _relativePath(string memory fromFile, string memory toFile) internal pure returns (string memory) {
        string[] memory fromParts = vm.split(fromFile, "/");
        string[] memory toParts = vm.split(toFile, "/");

        uint256 commonDepth = 0;
        while (
            commonDepth < fromParts.length && commonDepth < toParts.length
                && _eq(fromParts[commonDepth], toParts[commonDepth])
        ) {
            commonDepth++;
        }

        string memory result = ".";
        for (uint256 i = commonDepth; i + 1 < fromParts.length; i++) {
            result = string.concat(result, "/..");
        }
        for (uint256 i = commonDepth; i < toParts.length; i++) {
            result = string.concat(result, "/", toParts[i]);
        }
        return result;
    }

    function _fileNameNoExt(string memory file) private pure returns (string memory) {
        string[] memory fileParts = vm.split(file, "/");
        string[] memory parts = vm.split(fileParts[fileParts.length - 1], ".");
        return parts[0];
    }

    function _eq(string memory a, string memory b) private pure returns (bool) {
        return keccak256(_asBytes(a)) == keccak256(_asBytes(b));
    }
}

/// A utility struct for writing to a file with indentation.

struct FileWriter {
    string outFile;
    uint256 indent;
}

using FileWriterLib for FileWriter;

library FileWriterLib {
    Vm private constant vm = StdConstants.VM;

    function from(string memory outFile) internal returns (FileWriter memory) {
        if (vm.exists(outFile)) {
            vm.removeFile(outFile);
        }
        return FileWriter({outFile: outFile, indent: 0});
    }

    function write(FileWriter memory self, string memory content) internal {
        vm.writeLine(self.outFile, _indentStr(self.indent, content));
    }

    function write(FileWriter memory self) internal {
        self.write("");
    }

    function write(FileWriter memory self, string memory c1, string memory c2) internal {
        self.write(string.concat(c1, c2));
    }

    function write(FileWriter memory self, string memory c1, string memory c2, string memory c3) internal {
        self.write(string.concat(c1, c2, c3));
    }

    function write(FileWriter memory self, string memory c1, string memory c2, string memory c3, string memory c4)
        internal
    {
        self.write(string.concat(c1, c2, c3, c4));
    }

    function write(
        FileWriter memory self,
        string memory c1,
        string memory c2,
        string memory c3,
        string memory c4,
        string memory c5
    ) internal {
        self.write(string.concat(c1, c2, c3, c4, c5));
    }

    function startBlock(FileWriter memory self, string memory content) internal {
        self.write(string.concat(content, " {"));
        self.indent++;
    }

    function startBlock(FileWriter memory self, string memory c1, string memory c2) internal {
        self.startBlock(string.concat(c1, c2));
    }

    function startBlock(FileWriter memory self, string memory c1, string memory c2, string memory c3) internal {
        self.startBlock(string.concat(c1, c2, c3));
    }

    function startBlock(FileWriter memory self, string memory c1, string memory c2, string memory c3, string memory c4)
        internal
    {
        self.startBlock(string.concat(c1, c2, c3, c4));
    }

    function startBlock(
        FileWriter memory self,
        string memory c1,
        string memory c2,
        string memory c3,
        string memory c4,
        string memory c5
    ) internal {
        self.startBlock(string.concat(c1, c2, c3, c4, c5));
    }

    function endBlock(FileWriter memory self) internal {
        self.indent--;
        self.write("}");
    }

    function startExpr(FileWriter memory self, string memory content) internal {
        self.write(content, " (");
        self.indent++;
    }

    function endExpr(FileWriter memory self) internal {
        self.indent--;
        self.write(")");
    }

    function _indentStr(uint256 indent, string memory content) internal pure returns (string memory res) {
        uint256 indentLen = indent * 4;
        bytes memory resBytes = new bytes(indentLen + _length(content));
        for (uint256 i = 0; i < indentLen; i++) {
            resBytes[i] = " ";
        }
        for (uint256 i = 0; i < _length(content); i++) {
            resBytes[indentLen + i] = _asBytes(content)[i];
        }
        return _asStr(resBytes);
    }
}

function _asStr(bytes memory b) pure returns (string memory res) {
    assembly {
        res := b
    }
}

function _asBytes(string memory s) pure returns (bytes memory res) {
    assembly {
        res := s
    }
}

function _length(string memory s) pure returns (uint256) {
    return _asBytes(s).length;
}

function _subStr(string memory s, uint256 start, uint256 end) pure returns (string memory res) {
    bytes memory b = _asBytes(s);
    bytes memory resBytes = new bytes(end - start);
    for (uint256 i = start; i < end; i++) {
        resBytes[i - start] = b[i];
    }
    return _asStr(resBytes);
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.30;

import {Script} from "forge-std/src/Script.sol";
import {StdConstants} from "forge-std/src/StdConstants.sol";
import {Vm} from "forge-std/src/Vm.sol";
import {console} from "forge-std/src/console.sol";

struct AddOnlyStringSet {
    mapping(string => bool) __isElm;
    string[] __elms;
}

library AddOnlyStringSetLib {
    function add(AddOnlyStringSet storage self, string memory s) internal {
        if (!self.__isElm[s]) {
            self.__isElm[s] = true;
            self.__elms.push(s);
        }
    }

    function contains(AddOnlyStringSet storage self, string memory s) internal view returns (bool) {
        return self.__isElm[s];
    }

    function len(AddOnlyStringSet storage self) internal view returns (uint256) {
        return self.__elms.length;
    }

    function get(AddOnlyStringSet storage self, uint256 val) internal view returns (string memory) {
        return self.__elms[val];
    }
}

using AddOnlyStringSetLib for AddOnlyStringSet;

/// @dev See https://eips.ethereum.org/EIPS/eip-712#definition-of-typed-structured-data-%F0%9D%95%8A
/// Supported field types: atomic types, `bytes`, `string`, structs, and one-dimensional dynamic arrays of
/// those (`T[]`). Fixed-length arrays (`T[N]`) and nested arrays (`T[][]`) are rejected at generation time.
contract GenEIP712 is Script {
    AddOnlyStringSet internal _atomicTypes;
    AddOnlyStringSet internal _atomicArrayTypes;

    function _setAtomicType(string memory typeName) internal {
        _atomicTypes.add(typeName);
        _atomicArrayTypes.add(string.concat(typeName, "[]"));
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
    bool internal needEncodeBytes;
    bool internal needEncodeString;
    AddOnlyStringSet internal _arrayTypesToEncode;

    function run(
        string memory filePath,
        string memory interfaceName,
        string[] memory independentTypes,
        string memory outFile
    ) public {
        string memory joinedIndependentTypes = vm.serializeJsonType("string[]", abi.encode(independentTypes));
        for (uint256 i = 0; i < independentTypes.length; ++i) {
            isIndependentTypes[independentTypes[i]] = true;
        }
        console.log("Generating EIP712 info for : %s", filePath);
        console.log("Output file                : %s", outFile);
        console.log("Interface to generate      : %s", interfaceName);
        console.log("Indenendent types          : %s", joinedIndependentTypes);

        Eip712Info[] memory infos = getEip712Info(filePath);
        FileWriter memory out = FileWriterLib.from(outFile);

        out.write("// SPDX-License-Identifier: GPL-3.0-or-later");
        out.write("pragma solidity ^0.8.30;");
        out.write();
        out.write("/* GENERATED FILE. DO NOT EDIT DIRECTLY.");
        out.write(
            string.concat(
                "FOUNDRY_PROFILE=v2-script forge script script/GenEIP712.sol -- '",
                filePath,
                "' '",
                interfaceName,
                "' '",
                joinedIndependentTypes,
                "' '",
                outFile,
                "'"
            )
        );
        out.write("*/");
        out.write();
        out.write("import {", interfaceName, "} from \"", _relativePath(outFile, filePath), "\";");
        for (uint256 i = 0; i < independentTypes.length; ++i) {
            out.write(
                string.concat("import {", independentTypes[i], "} from \"", _relativePath(outFile, filePath), "\";")
            );
        }
        out.write();
        out.write(
            "/// @notice Generate EIP712 `encodeData` function for types in ", interfaceName, " based on specification:"
        );
        out.write("/// https://eips.ethereum.org/EIPS/eip-712#definition-of-encodedata");
        out.write(
            "/// @dev tempReplaceMem for typeHash is ALWAYS written after the other replacements, because of out-of-region memory write."
        );
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

            out.write("function encodeData(", typeName, " memory data) internal pure");
            out.indent++;
            string[] memory typePart = vm.split(infos[i].Type, ")"); // we will add ')' later when printing

            string[] memory fields =
                vm.split(_subStr(typePart[0], vm.indexOf(typePart[0], "(") + 1, _length(typePart[0])), ",");

            for (uint256 j = 0; j < fields.length; j++) {
                string[] memory typeAndName = vm.split(fields[j], " ");
                string memory tp = typeAndName[0];
                string memory name = typeAndName[1];

                if (_atomicTypes.contains(tp)) {
                    continue;
                }
                string memory ofsLabel = vm.toString(j * 32);

                if (_eq(tp, "bytes")) {
                    needEncodeBytes = true;
                } else if (_eq(tp, "string")) {
                    needEncodeString = true;
                } else if (vm.contains(tp, "[]")) {
                    // Only one-dimensional dynamic arrays (`T[]`). A nested array splits into 3+ parts.
                    string[] memory parts = vm.split(tp, "[");
                    require(parts.length == 2, string.concat("unsupported hashing for type ", tp));

                    string memory valueType = parts[0];
                    if (_eq(valueType, "bytes")) needEncodeBytes = true;
                    else if (_eq(valueType, "string")) needEncodeString = true;

                    if (
                        isIndependentTypes[valueType] || _eq(valueType, "bytes") || _eq(valueType, "string")
                            || _atomicTypes.contains(valueType)
                    ) {
                        _arrayTypesToEncode.add(tp);
                    } else {
                        _arrayTypesToEncode.add(string.concat(interfaceName, ".", tp));
                    }
                } else {
                    // A fixed-length array (`T[N]`) has no `[]`, so it lands here and is rejected.
                    require(!vm.contains(tp, "["), string.concat("unsupported hashing for type ", tp));
                }

                out.write("tempReplaceMem(_mPos(data), ", ofsLabel, ", encodeData(data.", name, "))");
            }

            /// NOTICE that the last char ")" so typePart[typePart.length - 1] is EMPTY
            {
                // output the raw computation for reader to verify by themselves
                out.write("/* TypeHash calculation: keccak256(");
                out.indent++;
                for (uint256 typeI = 0; typeI + 1 < typePart.length; ++typeI) {
                    out.write("\"", typePart[typeI], ")\" ");
                }
                out.indent--;
                out.write("); */");
            }
            out.write("tempReplaceMem(_mPos(data), -32, ", vm.toString(infos[i].Hash), ")");

            out.write("returns (bytes32 res)");
            out.indent--;
            out.startBlock();
            out.write("assembly { res := keccak256(sub(data, 32), ", vm.toString(fields.length * 32 + 32), ") }");
            out.endBlock();

            out.write();
            out.startBlock("function _mPos(", typeName, " memory data) private pure returns (bytes32 res)");
            out.write("assembly { res := data }");
            out.endBlock();
        }

        if (needEncodeBytes) {
            out.write();
            out.startBlock("function encodeData(bytes memory data) internal pure returns (bytes32 res)");
            out.write("assembly { res := keccak256(add(data, 32), mload(data)) }");
            out.endBlock();
        }

        if (needEncodeString) {
            out.write();
            out.startBlock("function encodeData(string memory data) internal pure returns (bytes32 res)");
            out.write("assembly { res := keccak256(add(data, 32), mload(data)) }");
            out.endBlock();
        }

        for (uint256 i = 0; i < _arrayTypesToEncode.len(); ++i) {
            string memory arrTp = _arrayTypesToEncode.get(i);
            string memory valueType = vm.split(arrTp, "[")[0];

            out.write();
            out.startBlock("function encodeData(", arrTp, " memory data) internal pure returns (bytes32 res)");
            // Only dynamic arrays reach here. The `add(data, 32)` below skips their length word; a
            // fixed-length memory array has no length word, which is why those are rejected above.
            out.write("uint256 n = data.length;");
            if (_atomicTypes.contains(valueType)) {
                out.write("assembly { res := keccak256(add(data, 32), shl(5, n)) }");
            } else {
                out.write("bytes32[] memory encodedData = new bytes32[](n);");
                out.write("for (uint256 i = 0; i < n; ++i) encodedData[i] = encodeData(data[i]);");
                out.write("assembly { res := keccak256(add(encodedData, 32), shl(5, n)) }");
            }

            out.endBlock();
        }

        out.write();
        out.write("// ========== Helper functions ==========");

        out.write();
        out.startBlock("modifier tempReplaceMem(bytes32 mPos, int256 ofs, bytes32 val)");
        out.write("bytes32 temp;");
        out.write("assembly { temp := mload(add(mPos, ofs)) mstore(add(mPos, ofs), val) }");
        out.write("_;");
        out.write("assembly { mstore(add(mPos, ofs), temp) }");
        out.endBlock();

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

    function startBlock(FileWriter memory self) internal {
        self.write("{");
        self.indent++;
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

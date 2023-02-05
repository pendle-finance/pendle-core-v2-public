/// @use-src 6:"contracts/core/libraries/TokenHelper.sol", 9:"contracts/interfaces/IPActionMintRedeem.sol", 19:"contracts/router/ActionMintRedeem.sol", 20:"contracts/router/base/ActionBaseMintRedeem.sol"
object "ActionMintRedeem_6066" {
    code {
        {
            /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
            let _1 := memoryguard(0x80)
            mstore(64, _1)
            if callvalue() { revert(0, 0) }
            let _2 := datasize("ActionMintRedeem_6066_deployed")
            codecopy(_1, dataoffset("ActionMintRedeem_6066_deployed"), _2)
            return(_1, _2)
        }
    }
    /// @use-src 6:"contracts/core/libraries/TokenHelper.sol", 19:"contracts/router/ActionMintRedeem.sol", 20:"contracts/router/base/ActionBaseMintRedeem.sol", 26:"node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol", 27:"node_modules/@openzeppelin/contracts/utils/Address.sol"
    object "ActionMintRedeem_6066_deployed" {
        code {
            {
                /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                let _1 := memoryguard(0x80)
                mstore(64, _1)
                if iszero(lt(calldatasize(), 4))
                {
                    switch shr(224, calldataload(0))
                    case 0x1a8631b2 {
                        if callvalue() { revert(0, 0) }
                        let param, param_1, param_2, param_3 := abi_decode_addresst_addresst_uint256t_uint256(calldatasize())
                        let _2 := sub(shl(160, 1), 1)
                        let _3 := and(/** @src 19:3464:3480  "IPYieldToken(YT)" */ param_1, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _2)
                        /// @src 19:3464:3485  "IPYieldToken(YT).SY()"
                        mstore(_1, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ shl(224, 0xafd27bf5))
                        /// @src 19:3464:3485  "IPYieldToken(YT).SY()"
                        let _4 := 32
                        let _5 := staticcall(gas(), _3, _1, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 4, /** @src 19:3464:3485  "IPYieldToken(YT).SY()" */ _1, _4)
                        if iszero(_5)
                        {
                            /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                            let pos := mload(64)
                            returndatacopy(pos, 0, returndatasize())
                            revert(pos, returndatasize())
                        }
                        /// @src 19:3464:3485  "IPYieldToken(YT).SY()"
                        let expr := /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0
                        /// @src 19:3464:3485  "IPYieldToken(YT).SY()"
                        if _5
                        {
                            let _6 := _4
                            if gt(_4, returndatasize()) { _6 := returndatasize() }
                            finalize_allocation(_1, _6)
                            expr := abi_decode_address_fromMemory(_1, add(_1, _6))
                        }
                        /// @src 6:904:961  "if (amount != 0) token.safeTransferFrom(from, to, amount)"
                        if /** @src 6:908:919  "amount != 0" */ iszero(iszero(param_2))
                        /// @src 6:904:961  "if (amount != 0) token.safeTransferFrom(from, to, amount)"
                        {
                            /// @src 6:954:960  "amount"
                            fun_safeTransferFrom(/** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ and(/** @src 20:5215:5225  "IERC20(SY)" */ expr, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _2), /** @src 20:5227:5237  "msg.sender" */ caller(), /** @src 6:954:960  "amount" */ param_1, param_2)
                        }
                        /// @src 20:5283:5326  "IPYieldToken(YT).mintPY(receiver, receiver)"
                        let _7 := /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(64)
                        /// @src 20:5283:5326  "IPYieldToken(YT).mintPY(receiver, receiver)"
                        mstore(_7, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ shl(224, 0xdb74aa15))
                        let _8 := and(param, _2)
                        mstore(/** @src 20:5283:5326  "IPYieldToken(YT).mintPY(receiver, receiver)" */ add(_7, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 4), _8)
                        mstore(add(/** @src 20:5283:5326  "IPYieldToken(YT).mintPY(receiver, receiver)" */ _7, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 36), _8)
                        /// @src 20:5283:5326  "IPYieldToken(YT).mintPY(receiver, receiver)"
                        let _9 := call(gas(), _3, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0, /** @src 20:5283:5326  "IPYieldToken(YT).mintPY(receiver, receiver)" */ _7, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 68, /** @src 20:5283:5326  "IPYieldToken(YT).mintPY(receiver, receiver)" */ _7, /** @src 19:3464:3485  "IPYieldToken(YT).SY()" */ _4)
                        /// @src 20:5283:5326  "IPYieldToken(YT).mintPY(receiver, receiver)"
                        if iszero(_9)
                        {
                            /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                            let pos_1 := mload(64)
                            returndatacopy(pos_1, 0, returndatasize())
                            revert(pos_1, returndatasize())
                        }
                        /// @src 20:5283:5326  "IPYieldToken(YT).mintPY(receiver, receiver)"
                        let expr_1 := /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0
                        /// @src 20:5283:5326  "IPYieldToken(YT).mintPY(receiver, receiver)"
                        if _9
                        {
                            let _10 := /** @src 19:3464:3485  "IPYieldToken(YT).SY()" */ _4
                            /// @src 20:5283:5326  "IPYieldToken(YT).mintPY(receiver, receiver)"
                            if gt(/** @src 19:3464:3485  "IPYieldToken(YT).SY()" */ _4, /** @src 20:5283:5326  "IPYieldToken(YT).mintPY(receiver, receiver)" */ returndatasize()) { _10 := returndatasize() }
                            finalize_allocation(_7, _10)
                            /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                            if slt(sub(/** @src 20:5283:5326  "IPYieldToken(YT).mintPY(receiver, receiver)" */ add(_7, _10), /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _7), /** @src 19:3464:3485  "IPYieldToken(YT).SY()" */ _4)
                            /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                            { revert(0, 0) }
                            /// @src 20:5283:5326  "IPYieldToken(YT).mintPY(receiver, receiver)"
                            expr_1 := /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(_7)
                        }
                        /// @src 20:5336:5418  "if (netPyOut < minPyOut) revert Errors.RouterInsufficientPYOut(netPyOut, minPyOut)"
                        if /** @src 20:5340:5359  "netPyOut < minPyOut" */ lt(expr_1, param_3)
                        /// @src 20:5336:5418  "if (netPyOut < minPyOut) revert Errors.RouterInsufficientPYOut(netPyOut, minPyOut)"
                        {
                            /// @src 20:5368:5418  "Errors.RouterInsufficientPYOut(netPyOut, minPyOut)"
                            let _11 := /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(64)
                            /// @src 20:5368:5418  "Errors.RouterInsufficientPYOut(netPyOut, minPyOut)"
                            mstore(_11, shl(224, 0xca935dfd))
                            /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                            mstore(/** @src 20:5368:5418  "Errors.RouterInsufficientPYOut(netPyOut, minPyOut)" */ add(_11, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 4), expr_1)
                            mstore(add(/** @src 20:5368:5418  "Errors.RouterInsufficientPYOut(netPyOut, minPyOut)" */ _11, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 36), param_3)
                            /// @src 20:5368:5418  "Errors.RouterInsufficientPYOut(netPyOut, minPyOut)"
                            revert(_11, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 68)
                        }
                        /// @src 19:3530:3587  "MintPyFromSy(msg.sender, receiver, YT, netSyIn, netPyOut)"
                        let _12 := /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(64)
                        mstore(_12, param_2)
                        mstore(add(_12, /** @src 19:3464:3485  "IPYieldToken(YT).SY()" */ _4), /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ expr_1)
                        /// @src 19:3530:3587  "MintPyFromSy(msg.sender, receiver, YT, netSyIn, netPyOut)"
                        log4(_12, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 64, /** @src 19:3530:3587  "MintPyFromSy(msg.sender, receiver, YT, netSyIn, netPyOut)" */ 0x52e05e4badd3463bad837f42fe3ba58c739d1b3081cff9bb6eb02a24034d455d, /** @src 20:5227:5237  "msg.sender" */ caller(), /** @src 19:3530:3587  "MintPyFromSy(msg.sender, receiver, YT, netSyIn, netPyOut)" */ _8, _3)
                        /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                        let memPos := mload(64)
                        mstore(memPos, expr_1)
                        return(memPos, /** @src 19:3464:3485  "IPYieldToken(YT).SY()" */ _4)
                    }
                    case /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0x339748cb {
                        if callvalue() { revert(0, 0) }
                        let param_4, param_5, param_6, param_7 := abi_decode_addresst_addresst_uint256t_uint256(calldatasize())
                        let _13 := sub(shl(160, 1), 1)
                        let _14 := and(/** @src 20:5616:5632  "IPYieldToken(YT)" */ param_5, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _13)
                        /// @src 20:5616:5637  "IPYieldToken(YT).PT()"
                        let _15 := /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(64)
                        /// @src 20:5616:5637  "IPYieldToken(YT).PT()"
                        mstore(_15, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ shl(226, 0x36501cf5))
                        /// @src 20:5616:5637  "IPYieldToken(YT).PT()"
                        let _16 := 32
                        let _17 := staticcall(gas(), _14, _15, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 4, /** @src 20:5616:5637  "IPYieldToken(YT).PT()" */ _15, _16)
                        if iszero(_17)
                        {
                            /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                            let pos_2 := mload(64)
                            returndatacopy(pos_2, 0, returndatasize())
                            revert(pos_2, returndatasize())
                        }
                        /// @src 20:5616:5637  "IPYieldToken(YT).PT()"
                        let expr_2 := /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0
                        /// @src 20:5616:5637  "IPYieldToken(YT).PT()"
                        if _17
                        {
                            let _18 := _16
                            if gt(_16, returndatasize()) { _18 := returndatasize() }
                            finalize_allocation(_15, _18)
                            expr_2 := abi_decode_address_fromMemory(_15, add(_15, _18))
                        }
                        /// @src 6:908:919  "amount != 0"
                        let _19 := iszero(iszero(param_6))
                        /// @src 6:904:961  "if (amount != 0) token.safeTransferFrom(from, to, amount)"
                        if /** @src 6:908:919  "amount != 0" */ _19
                        /// @src 6:904:961  "if (amount != 0) token.safeTransferFrom(from, to, amount)"
                        {
                            /// @src 6:954:960  "amount"
                            fun_safeTransferFrom(/** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ and(/** @src 20:5662:5672  "IERC20(PT)" */ expr_2, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _13), /** @src 20:5674:5684  "msg.sender" */ caller(), /** @src 6:954:960  "amount" */ param_5, param_6)
                        }
                        /// @src 20:5731:5759  "IPYieldToken(YT).isExpired()"
                        let _20 := /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(64)
                        /// @src 20:5731:5759  "IPYieldToken(YT).isExpired()"
                        mstore(_20, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ shl(226, 0x0bc4ed83))
                        /// @src 20:5731:5759  "IPYieldToken(YT).isExpired()"
                        let _21 := staticcall(gas(), _14, _20, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 4, /** @src 20:5731:5759  "IPYieldToken(YT).isExpired()" */ _20, /** @src 20:5616:5637  "IPYieldToken(YT).PT()" */ _16)
                        /// @src 20:5731:5759  "IPYieldToken(YT).isExpired()"
                        if iszero(_21)
                        {
                            /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                            let pos_3 := mload(64)
                            returndatacopy(pos_3, 0, returndatasize())
                            revert(pos_3, returndatasize())
                        }
                        /// @src 20:5731:5759  "IPYieldToken(YT).isExpired()"
                        let expr_3 := /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0
                        /// @src 20:5731:5759  "IPYieldToken(YT).isExpired()"
                        if _21
                        {
                            let _22 := /** @src 20:5616:5637  "IPYieldToken(YT).PT()" */ _16
                            /// @src 20:5731:5759  "IPYieldToken(YT).isExpired()"
                            if gt(/** @src 20:5616:5637  "IPYieldToken(YT).PT()" */ _16, /** @src 20:5731:5759  "IPYieldToken(YT).isExpired()" */ returndatasize()) { _22 := returndatasize() }
                            finalize_allocation(_20, _22)
                            expr_3 := abi_decode_bool_fromMemory(_20, add(_20, _22))
                        }
                        /// @src 20:5770:5838  "if (needToBurnYt) _transferFrom(IERC20(YT), msg.sender, YT, netPyIn)"
                        if /** @src 20:5730:5759  "!IPYieldToken(YT).isExpired()" */ iszero(expr_3)
                        /// @src 20:5770:5838  "if (needToBurnYt) _transferFrom(IERC20(YT), msg.sender, YT, netPyIn)"
                        {
                            /// @src 6:904:961  "if (amount != 0) token.safeTransferFrom(from, to, amount)"
                            if /** @src 6:908:919  "amount != 0" */ _19
                            /// @src 6:904:961  "if (amount != 0) token.safeTransferFrom(from, to, amount)"
                            {
                                /// @src 6:954:960  "amount"
                                fun_safeTransferFrom(_14, /** @src 20:5674:5684  "msg.sender" */ caller(), /** @src 6:954:960  "amount" */ param_5, param_6)
                            }
                        }
                        /// @src 20:5860:5895  "IPYieldToken(YT).redeemPY(receiver)"
                        let _23 := /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(64)
                        /// @src 20:5860:5895  "IPYieldToken(YT).redeemPY(receiver)"
                        mstore(_23, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ shl(224, 0xbcb7ea5d))
                        let _24 := and(param_4, _13)
                        mstore(/** @src 20:5860:5895  "IPYieldToken(YT).redeemPY(receiver)" */ add(_23, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 4), _24)
                        /// @src 20:5860:5895  "IPYieldToken(YT).redeemPY(receiver)"
                        let _25 := call(gas(), _14, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0, /** @src 20:5860:5895  "IPYieldToken(YT).redeemPY(receiver)" */ _23, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 36, /** @src 20:5860:5895  "IPYieldToken(YT).redeemPY(receiver)" */ _23, /** @src 20:5616:5637  "IPYieldToken(YT).PT()" */ _16)
                        /// @src 20:5860:5895  "IPYieldToken(YT).redeemPY(receiver)"
                        if iszero(_25)
                        {
                            /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                            let pos_4 := mload(64)
                            returndatacopy(pos_4, 0, returndatasize())
                            revert(pos_4, returndatasize())
                        }
                        /// @src 20:5860:5895  "IPYieldToken(YT).redeemPY(receiver)"
                        let expr_4 := /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0
                        /// @src 20:5860:5895  "IPYieldToken(YT).redeemPY(receiver)"
                        if _25
                        {
                            let _26 := /** @src 20:5616:5637  "IPYieldToken(YT).PT()" */ _16
                            /// @src 20:5860:5895  "IPYieldToken(YT).redeemPY(receiver)"
                            if gt(/** @src 20:5616:5637  "IPYieldToken(YT).PT()" */ _16, /** @src 20:5860:5895  "IPYieldToken(YT).redeemPY(receiver)" */ returndatasize()) { _26 := returndatasize() }
                            finalize_allocation(_23, _26)
                            /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                            if slt(sub(/** @src 20:5860:5895  "IPYieldToken(YT).redeemPY(receiver)" */ add(_23, _26), /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _23), /** @src 20:5616:5637  "IPYieldToken(YT).PT()" */ _16)
                            /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                            { revert(0, 0) }
                            /// @src 20:5860:5895  "IPYieldToken(YT).redeemPY(receiver)"
                            expr_4 := /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(_23)
                        }
                        /// @src 20:5905:5987  "if (netSyOut < minSyOut) revert Errors.RouterInsufficientSyOut(netSyOut, minSyOut)"
                        if /** @src 20:5909:5928  "netSyOut < minSyOut" */ lt(expr_4, param_7)
                        /// @src 20:5905:5987  "if (netSyOut < minSyOut) revert Errors.RouterInsufficientSyOut(netSyOut, minSyOut)"
                        {
                            /// @src 20:5937:5987  "Errors.RouterInsufficientSyOut(netSyOut, minSyOut)"
                            let _27 := /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(64)
                            /// @src 20:5937:5987  "Errors.RouterInsufficientSyOut(netSyOut, minSyOut)"
                            mstore(_27, shl(225, 0x05221cf3))
                            /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                            mstore(/** @src 20:5937:5987  "Errors.RouterInsufficientSyOut(netSyOut, minSyOut)" */ add(_27, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 4), expr_4)
                            mstore(add(/** @src 20:5937:5987  "Errors.RouterInsufficientSyOut(netSyOut, minSyOut)" */ _27, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 36), param_7)
                            /// @src 20:5937:5987  "Errors.RouterInsufficientSyOut(netSyOut, minSyOut)"
                            revert(_27, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 68)
                        }
                        /// @src 19:3900:3957  "RedeemPyToSy(msg.sender, receiver, YT, netPyIn, netSyOut)"
                        let _28 := /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(64)
                        mstore(_28, param_6)
                        mstore(add(_28, /** @src 20:5616:5637  "IPYieldToken(YT).PT()" */ _16), /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ expr_4)
                        /// @src 19:3900:3957  "RedeemPyToSy(msg.sender, receiver, YT, netPyIn, netSyOut)"
                        log4(_28, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 64, /** @src 19:3900:3957  "RedeemPyToSy(msg.sender, receiver, YT, netPyIn, netSyOut)" */ 0x31af33f80f4b396e3d4e42b38ecd3e022883a9bf689fd63f47afbe1d389cb6e7, /** @src 20:5674:5684  "msg.sender" */ caller(), /** @src 19:3900:3957  "RedeemPyToSy(msg.sender, receiver, YT, netPyIn, netSyOut)" */ _24, _14)
                        /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                        let memPos_1 := mload(64)
                        mstore(memPos_1, expr_4)
                        return(memPos_1, /** @src 20:5616:5637  "IPYieldToken(YT).PT()" */ _16)
                    }
                    case /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0x443e6512 {
                        let param_8, param_9, param_10, param_11 := abi_decode_addresst_addresst_uint256t_struct_TokenInput_calldata(calldatasize())
                        /// @src 20:1105:1113  "inp.data"
                        let _29 := add(param_11, 160)
                        let _30 := access_calldata_tail_struct_SwapData_calldata(param_11, _29)
                        /// @src 20:1105:1122  "inp.data.swapType"
                        let returnValue := /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0
                        let value := calldataload(_30)
                        if iszero(lt(value, 4)) { revert(0, 0) }
                        /// @src 20:1133:1155  "uint256 netTokenMintSy"
                        let var_netTokenMintSy := /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0
                        /// @src 20:1166:1992  "if (swapType == SwapType.NONE) {..."
                        switch /** @src 20:1170:1195  "swapType == SwapType.NONE" */ iszero(value)
                        case /** @src 20:1166:1992  "if (swapType == SwapType.NONE) {..." */ 0 {
                            /// @src 20:1325:1992  "if (swapType == SwapType.ETH_WETH) {..."
                            switch /** @src 20:1329:1358  "swapType == SwapType.ETH_WETH" */ eq(value, /** @src 20:1341:1358  "SwapType.ETH_WETH" */ 3)
                            case /** @src 20:1325:1992  "if (swapType == SwapType.ETH_WETH) {..." */ 0 {
                                /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                                let _31 := sub(shl(160, 1), 1)
                                /// @src 20:1578:1749  "if (inp.tokenIn == NATIVE) _transferIn(NATIVE, msg.sender, inp.netTokenIn);..."
                                switch /** @src 20:1582:1603  "inp.tokenIn == NATIVE" */ iszero(/** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ and(/** @src 20:1582:1593  "inp.tokenIn" */ read_from_calldatat_address(param_11), /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _31))
                                case /** @src 20:1578:1749  "if (inp.tokenIn == NATIVE) _transferIn(NATIVE, msg.sender, inp.netTokenIn);..." */ 0 {
                                    /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                                    let _32 := and(/** @src 20:1692:1703  "inp.tokenIn" */ read_from_calldatat_address(param_11), /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _31)
                                    /// @src 20:1718:1732  "inp.pendleSwap"
                                    let expr_5 := read_from_calldatat_address(add(param_11, 128))
                                    /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                                    let value_1 := calldataload(/** @src 20:1734:1748  "inp.netTokenIn" */ add(param_11, 32))
                                    /// @src 6:904:961  "if (amount != 0) token.safeTransferFrom(from, to, amount)"
                                    if /** @src 6:908:919  "amount != 0" */ iszero(iszero(value_1))
                                    /// @src 6:904:961  "if (amount != 0) token.safeTransferFrom(from, to, amount)"
                                    {
                                        /// @src 6:954:960  "amount"
                                        fun_safeTransferFrom(_32, /** @src 20:1706:1716  "msg.sender" */ caller(), /** @src 6:954:960  "amount" */ expr_5, value_1)
                                    }
                                }
                                default /// @src 20:1578:1749  "if (inp.tokenIn == NATIVE) _transferIn(NATIVE, msg.sender, inp.netTokenIn);..."
                                {
                                    /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                                    if iszero(/** @src 6:628:647  "msg.value == amount" */ eq(/** @src 6:628:637  "msg.value" */ callvalue(), /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ calldataload(/** @src 20:1637:1651  "inp.netTokenIn" */ add(param_11, 32))))
                                    /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                                    {
                                        let memPtr := mload(64)
                                        mstore(memPtr, shl(229, 4594637))
                                        mstore(add(memPtr, 4), /** @src 20:1637:1651  "inp.netTokenIn" */ 32)
                                        /// @src 6:352:362  "address(0)"
                                        mstore(/** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ add(memPtr, 36), 12)
                                        mstore(/** @src 6:352:362  "address(0)" */ add(/** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ memPtr, /** @src 6:352:362  "address(0)" */ 68), /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ "eth mismatch")
                                        revert(memPtr, 100)
                                    }
                                }
                                let _33 := and(/** @src 20:1781:1795  "inp.pendleSwap" */ read_from_calldatat_address(add(param_11, 128)), /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _31)
                                /// @src 20:1826:1847  "inp.tokenIn == NATIVE"
                                let expr_6 := iszero(/** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ and(/** @src 20:1826:1837  "inp.tokenIn" */ read_from_calldatat_address(param_11), /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _31))
                                /// @src 20:1826:1868  "inp.tokenIn == NATIVE ? inp.netTokenIn : 0"
                                let expr_7 := /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0
                                /// @src 20:1826:1868  "inp.tokenIn == NATIVE ? inp.netTokenIn : 0"
                                switch expr_6
                                case 0 {
                                    expr_7 := /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0
                                }
                                default /// @src 20:1826:1868  "inp.tokenIn == NATIVE ? inp.netTokenIn : 0"
                                {
                                    expr_7 := /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ calldataload(/** @src 20:1850:1864  "inp.netTokenIn" */ add(param_11, 32))
                                }
                                /// @src 20:1883:1894  "inp.tokenIn"
                                let expr_8 := read_from_calldatat_address(param_11)
                                /// @src 20:1912:1920  "inp.data"
                                let expr_offset := access_calldata_tail_struct_SwapData_calldata(param_11, _29)
                                /// @src 20:1764:1921  "IPSwapAggregator(inp.pendleSwap).swap{..."
                                if iszero(extcodesize(_33))
                                {
                                    /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                                    revert(0, 0)
                                }
                                /// @src 20:1764:1921  "IPSwapAggregator(inp.pendleSwap).swap{..."
                                let _34 := /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(64)
                                /// @src 20:1764:1921  "IPSwapAggregator(inp.pendleSwap).swap{..."
                                mstore(_34, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ shl(226, 0x0af6e08f))
                                /// @src 20:1764:1921  "IPSwapAggregator(inp.pendleSwap).swap{..."
                                let _35 := call(gas(), _33, expr_7, _34, sub(abi_encode_address_uint256_struct_SwapData_calldata(add(_34, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 4), /** @src 20:1764:1921  "IPSwapAggregator(inp.pendleSwap).swap{..." */ expr_8, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ calldataload(/** @src 20:1896:1910  "inp.netTokenIn" */ add(param_11, 32)), /** @src 20:1764:1921  "IPSwapAggregator(inp.pendleSwap).swap{..." */ expr_offset), _34), _34, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0)
                                /// @src 20:1764:1921  "IPSwapAggregator(inp.pendleSwap).swap{..."
                                if iszero(_35)
                                {
                                    /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                                    let pos_5 := mload(64)
                                    returndatacopy(pos_5, 0, returndatasize())
                                    revert(pos_5, returndatasize())
                                }
                                /// @src 20:1764:1921  "IPSwapAggregator(inp.pendleSwap).swap{..."
                                if _35
                                {
                                    finalize_allocation_8341(_34)
                                    /// @src 6:352:362  "address(0)"
                                    returnValue := /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0
                                }
                                /// @src 20:1935:1981  "netTokenMintSy = _selfBalance(inp.tokenMintSy)"
                                var_netTokenMintSy := /** @src 20:1952:1981  "_selfBalance(inp.tokenMintSy)" */ fun_selfBalance(/** @src 20:1965:1980  "inp.tokenMintSy" */ read_from_calldatat_address(add(param_11, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 64)))
                            }
                            default /// @src 20:1325:1992  "if (swapType == SwapType.ETH_WETH) {..."
                            {
                                /// @src 20:1386:1397  "inp.tokenIn"
                                let expr_9 := read_from_calldatat_address(param_11)
                                /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                                let value_2 := calldataload(/** @src 20:1411:1425  "inp.netTokenIn" */ add(param_11, 32))
                                fun_transferIn(expr_9, /** @src 20:1399:1409  "msg.sender" */ caller(), /** @src 20:1411:1425  "inp.netTokenIn" */ value_2)
                                /// @src 20:1457:1468  "inp.tokenIn"
                                let expr_10 := read_from_calldatat_address(param_11)
                                /// @src 20:1487:1501  "inp.netTokenIn"
                                fun_wrap_unwrap_ETH(expr_10, /** @src 20:1470:1485  "inp.tokenMintSy" */ read_from_calldatat_address(add(param_11, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 64)), /** @src 20:1487:1501  "inp.netTokenIn" */ value_2)
                                /// @src 20:1516:1547  "netTokenMintSy = inp.netTokenIn"
                                var_netTokenMintSy := value_2
                            }
                        }
                        default /// @src 20:1166:1992  "if (swapType == SwapType.NONE) {..."
                        {
                            /// @src 20:1223:1234  "inp.tokenIn"
                            let expr_11 := read_from_calldatat_address(param_11)
                            /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                            let value_3 := calldataload(/** @src 20:1248:1262  "inp.netTokenIn" */ add(param_11, 32))
                            fun_transferIn(expr_11, /** @src 20:1236:1246  "msg.sender" */ caller(), /** @src 20:1248:1262  "inp.netTokenIn" */ value_3)
                            /// @src 20:1277:1308  "netTokenMintSy = inp.netTokenIn"
                            var_netTokenMintSy := value_3
                        }
                        /// @src 20:2084:2137  "__mintSy(receiver, SY, netTokenMintSy, minSyOut, inp)"
                        let var_netSyOut := returnValue
                        /// @src 20:2453:2468  "inp.tokenMintSy"
                        let _36 := add(param_11, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 64)
                        let _37 := sub(shl(160, 1), 1)
                        /// @src 20:2453:2478  "inp.tokenMintSy == NATIVE"
                        let expr_12 := iszero(/** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ and(/** @src 20:2453:2468  "inp.tokenMintSy" */ read_from_calldatat_address(_36), /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _37))
                        /// @src 20:2453:2499  "inp.tokenMintSy == NATIVE ? netTokenMintSy : 0"
                        let expr_13 := returnValue
                        switch expr_12
                        case 0 { expr_13 := returnValue }
                        default { expr_13 := var_netTokenMintSy }
                        /// @src 20:2514:2522  "inp.bulk"
                        let _38 := add(param_11, 96)
                        /// @src 20:2510:2957  "if (inp.bulk != address(0)) {..."
                        switch /** @src 20:2514:2536  "inp.bulk != address(0)" */ iszero(iszero(/** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ and(/** @src 20:2514:2522  "inp.bulk" */ read_from_calldatat_address(_38), /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _37)))
                        case /** @src 20:2510:2957  "if (inp.bulk != address(0)) {..." */ 0 {
                            /// @src 20:2859:2874  "inp.tokenMintSy"
                            let expr_14 := read_from_calldatat_address(_36)
                            /// @src 20:2765:2946  "IStandardizedYield(SY).deposit{ value: netNative }(..."
                            let _39 := /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(64)
                            /// @src 20:2765:2946  "IStandardizedYield(SY).deposit{ value: netNative }(..."
                            mstore(_39, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ shl(224, 0x20e8c565))
                            mstore(/** @src 20:2765:2946  "IStandardizedYield(SY).deposit{ value: netNative }(..." */ add(_39, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 4), and(param_8, _37))
                            mstore(add(/** @src 20:2765:2946  "IStandardizedYield(SY).deposit{ value: netNative }(..." */ _39, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 36), and(expr_14, _37))
                            mstore(add(/** @src 20:2765:2946  "IStandardizedYield(SY).deposit{ value: netNative }(..." */ _39, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 68), var_netTokenMintSy)
                            mstore(add(/** @src 20:2765:2946  "IStandardizedYield(SY).deposit{ value: netNative }(..." */ _39, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 100), param_10)
                            /// @src 20:2765:2946  "IStandardizedYield(SY).deposit{ value: netNative }(..."
                            let _40 := call(gas(), /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ and(/** @src 20:2765:2787  "IStandardizedYield(SY)" */ param_9, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _37), /** @src 20:2765:2946  "IStandardizedYield(SY).deposit{ value: netNative }(..." */ expr_13, _39, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 132, /** @src 20:2765:2946  "IStandardizedYield(SY).deposit{ value: netNative }(..." */ _39, 32)
                            if iszero(_40)
                            {
                                /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                                let pos_6 := mload(64)
                                returndatacopy(pos_6, /** @src 20:1105:1122  "inp.data.swapType" */ returnValue, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ returndatasize())
                                revert(pos_6, returndatasize())
                            }
                            /// @src 20:2765:2946  "IStandardizedYield(SY).deposit{ value: netNative }(..."
                            let expr_15 := returnValue
                            if _40
                            {
                                let _41 := 32
                                if gt(_41, returndatasize()) { _41 := returndatasize() }
                                finalize_allocation(_39, _41)
                                /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                                if slt(sub(/** @src 20:2765:2946  "IStandardizedYield(SY).deposit{ value: netNative }(..." */ add(_39, _41), /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _39), /** @src 20:2765:2946  "IStandardizedYield(SY).deposit{ value: netNative }(..." */ 32)
                                /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                                { revert(0, 0) }
                                /// @src 20:2765:2946  "IStandardizedYield(SY).deposit{ value: netNative }(..."
                                expr_15 := /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(_39)
                            }
                            /// @src 20:2754:2946  "netSyOut = IStandardizedYield(SY).deposit{ value: netNative }(..."
                            var_netSyOut := expr_15
                        }
                        default /// @src 20:2510:2957  "if (inp.bulk != address(0)) {..."
                        {
                            /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                            let _42 := and(/** @src 20:2576:2584  "inp.bulk" */ read_from_calldatat_address(_38), /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _37)
                            /// @src 20:2563:2723  "IPBulkSeller(inp.bulk).swapExactTokenForSy{ value: netNative }(..."
                            let _43 := /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(64)
                            /// @src 20:2563:2723  "IPBulkSeller(inp.bulk).swapExactTokenForSy{ value: netNative }(..."
                            mstore(_43, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ shl(228, 0x0b276707))
                            /// @src 20:2563:2723  "IPBulkSeller(inp.bulk).swapExactTokenForSy{ value: netNative }(..."
                            let _44 := call(gas(), _42, expr_13, _43, sub(abi_encode_address_uint256_uint256(add(_43, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 4), /** @src 20:2563:2723  "IPBulkSeller(inp.bulk).swapExactTokenForSy{ value: netNative }(..." */ param_8, var_netTokenMintSy, param_10), _43), _43, 32)
                            if iszero(_44)
                            {
                                /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                                let pos_7 := mload(64)
                                returndatacopy(pos_7, /** @src 20:1105:1122  "inp.data.swapType" */ returnValue, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ returndatasize())
                                revert(pos_7, returndatasize())
                            }
                            /// @src 20:2563:2723  "IPBulkSeller(inp.bulk).swapExactTokenForSy{ value: netNative }(..."
                            let expr_16 := returnValue
                            if _44
                            {
                                let _45 := 32
                                if gt(_45, returndatasize()) { _45 := returndatasize() }
                                finalize_allocation(_43, _45)
                                /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                                if slt(sub(/** @src 20:2563:2723  "IPBulkSeller(inp.bulk).swapExactTokenForSy{ value: netNative }(..." */ add(_43, _45), /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _43), /** @src 20:2563:2723  "IPBulkSeller(inp.bulk).swapExactTokenForSy{ value: netNative }(..." */ 32)
                                /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                                { revert(0, 0) }
                                /// @src 20:2563:2723  "IPBulkSeller(inp.bulk).swapExactTokenForSy{ value: netNative }(..."
                                expr_16 := /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(_43)
                            }
                            /// @src 20:2552:2723  "netSyOut = IPBulkSeller(inp.bulk).swapExactTokenForSy{ value: netNative }(..."
                            var_netSyOut := expr_16
                        }
                        /// @src 19:894:907  "input.tokenIn"
                        let expr_17 := read_from_calldatat_address(param_11)
                        /// @src 19:866:950  "MintSyFromToken(msg.sender, input.tokenIn, SY, receiver, input.netTokenIn, netSyOut)"
                        let _46 := /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(64)
                        /// @src 19:866:950  "MintSyFromToken(msg.sender, input.tokenIn, SY, receiver, input.netTokenIn, netSyOut)"
                        log4(_46, sub(abi_encode_address_uint256_uint256(_46, param_8, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ calldataload(/** @src 19:923:939  "input.netTokenIn" */ add(param_11, 32)), /** @src 19:866:950  "MintSyFromToken(msg.sender, input.tokenIn, SY, receiver, input.netTokenIn, netSyOut)" */ var_netSyOut), _46), 0x71c7a44161eb32e4640f6c8f0586db5f1d2e03306e2c63bb2e0f7cd0a8fc690c, /** @src 19:882:892  "msg.sender" */ caller(), /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ and(/** @src 19:866:950  "MintSyFromToken(msg.sender, input.tokenIn, SY, receiver, input.netTokenIn, netSyOut)" */ expr_17, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _37), and(/** @src 19:866:950  "MintSyFromToken(msg.sender, input.tokenIn, SY, receiver, input.netTokenIn, netSyOut)" */ param_9, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _37))
                        let memPos_2 := mload(64)
                        mstore(memPos_2, var_netSyOut)
                        return(memPos_2, /** @src 19:923:939  "input.netTokenIn" */ 32)
                    }
                    case /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0x46eb2db6 {
                        let param_12, param_13, param_14, param_15 := abi_decode_addresst_addresst_uint256t_struct_TokenInput_calldata(calldatasize())
                        let _47 := sub(shl(160, 1), 1)
                        let _48 := and(/** @src 19:2083:2099  "IPYieldToken(YT)" */ param_13, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _47)
                        /// @src 19:2083:2104  "IPYieldToken(YT).SY()"
                        let _49 := /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(64)
                        /// @src 19:2083:2104  "IPYieldToken(YT).SY()"
                        mstore(_49, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ shl(224, 0xafd27bf5))
                        /// @src 19:2083:2104  "IPYieldToken(YT).SY()"
                        let _50 := 32
                        let _51 := staticcall(gas(), _48, _49, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 4, /** @src 19:2083:2104  "IPYieldToken(YT).SY()" */ _49, _50)
                        if iszero(_51)
                        {
                            /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                            let pos_8 := mload(64)
                            returndatacopy(pos_8, 0, returndatasize())
                            revert(pos_8, returndatasize())
                        }
                        /// @src 19:2083:2104  "IPYieldToken(YT).SY()"
                        let expr_18 := /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0
                        /// @src 19:2083:2104  "IPYieldToken(YT).SY()"
                        if _51
                        {
                            let _52 := _50
                            if gt(_50, returndatasize()) { _52 := returndatasize() }
                            finalize_allocation(_49, _52)
                            expr_18 := abi_decode_address_fromMemory(_49, add(_49, _52))
                        }
                        /// @ast-id 6249 @src 20:902:2144  "function _mintSyFromToken(..."
                        let /// @ast-id 6249
                        var_minSyOut := /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0
                        /// @src 20:1105:1113  "inp.data"
                        let _53 := add(param_15, 160)
                        /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                        let value_4 := calldataload(/** @src 20:1105:1113  "inp.data" */ access_calldata_tail_struct_SwapData_calldata(param_15, _53))
                        /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                        if iszero(lt(value_4, 4)) { revert(0, 0) }
                        /// @src 20:1133:1155  "uint256 netTokenMintSy"
                        let var_netTokenMintSy_1 := /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0
                        /// @src 20:1166:1992  "if (swapType == SwapType.NONE) {..."
                        switch /** @src 20:1170:1195  "swapType == SwapType.NONE" */ iszero(value_4)
                        case /** @src 20:1166:1992  "if (swapType == SwapType.NONE) {..." */ 0 {
                            /// @src 20:1325:1992  "if (swapType == SwapType.ETH_WETH) {..."
                            switch /** @src 20:1329:1358  "swapType == SwapType.ETH_WETH" */ eq(value_4, /** @src 20:1341:1358  "SwapType.ETH_WETH" */ 3)
                            case /** @src 20:1325:1992  "if (swapType == SwapType.ETH_WETH) {..." */ 0 {
                                /// @src 20:1578:1749  "if (inp.tokenIn == NATIVE) _transferIn(NATIVE, msg.sender, inp.netTokenIn);..."
                                switch /** @src 20:1582:1603  "inp.tokenIn == NATIVE" */ iszero(/** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ and(/** @src 20:1582:1593  "inp.tokenIn" */ read_from_calldatat_address(param_15), /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _47))
                                case /** @src 20:1578:1749  "if (inp.tokenIn == NATIVE) _transferIn(NATIVE, msg.sender, inp.netTokenIn);..." */ 0 {
                                    /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                                    let _54 := and(/** @src 20:1692:1703  "inp.tokenIn" */ read_from_calldatat_address(param_15), /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _47)
                                    /// @src 20:1718:1732  "inp.pendleSwap"
                                    let expr_19 := read_from_calldatat_address(add(param_15, 128))
                                    /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                                    let value_5 := calldataload(/** @src 20:1734:1748  "inp.netTokenIn" */ add(param_15, /** @src 19:2083:2104  "IPYieldToken(YT).SY()" */ _50))
                                    /// @src 6:904:961  "if (amount != 0) token.safeTransferFrom(from, to, amount)"
                                    if /** @src 6:908:919  "amount != 0" */ iszero(iszero(value_5))
                                    /// @src 6:904:961  "if (amount != 0) token.safeTransferFrom(from, to, amount)"
                                    {
                                        /// @src 6:954:960  "amount"
                                        fun_safeTransferFrom(_54, /** @src 20:1706:1716  "msg.sender" */ caller(), /** @src 6:954:960  "amount" */ expr_19, value_5)
                                    }
                                }
                                default /// @src 20:1578:1749  "if (inp.tokenIn == NATIVE) _transferIn(NATIVE, msg.sender, inp.netTokenIn);..."
                                {
                                    /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                                    if iszero(/** @src 6:628:647  "msg.value == amount" */ eq(/** @src 6:628:637  "msg.value" */ callvalue(), /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ calldataload(/** @src 20:1637:1651  "inp.netTokenIn" */ add(param_15, /** @src 19:2083:2104  "IPYieldToken(YT).SY()" */ _50))))
                                    /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                                    {
                                        let memPtr_1 := mload(64)
                                        mstore(memPtr_1, shl(229, 4594637))
                                        mstore(add(memPtr_1, 4), /** @src 19:2083:2104  "IPYieldToken(YT).SY()" */ _50)
                                        /// @src 6:352:362  "address(0)"
                                        mstore(/** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ add(memPtr_1, 36), 12)
                                        mstore(/** @src 6:352:362  "address(0)" */ add(/** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ memPtr_1, /** @src 6:352:362  "address(0)" */ 68), /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ "eth mismatch")
                                        revert(memPtr_1, 100)
                                    }
                                }
                                let _55 := and(/** @src 20:1781:1795  "inp.pendleSwap" */ read_from_calldatat_address(add(param_15, 128)), /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _47)
                                /// @src 20:1826:1847  "inp.tokenIn == NATIVE"
                                let expr_20 := iszero(/** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ and(/** @src 20:1826:1837  "inp.tokenIn" */ read_from_calldatat_address(param_15), /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _47))
                                /// @src 20:1826:1868  "inp.tokenIn == NATIVE ? inp.netTokenIn : 0"
                                let expr_21 := /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0
                                /// @src 20:1826:1868  "inp.tokenIn == NATIVE ? inp.netTokenIn : 0"
                                switch expr_20
                                case 0 {
                                    expr_21 := /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0
                                }
                                default /// @src 20:1826:1868  "inp.tokenIn == NATIVE ? inp.netTokenIn : 0"
                                {
                                    expr_21 := /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ calldataload(/** @src 20:1850:1864  "inp.netTokenIn" */ add(param_15, /** @src 19:2083:2104  "IPYieldToken(YT).SY()" */ _50))
                                }
                                /// @src 20:1883:1894  "inp.tokenIn"
                                let expr_22 := read_from_calldatat_address(param_15)
                                /// @src 20:1912:1920  "inp.data"
                                let expr_offset_1 := access_calldata_tail_struct_SwapData_calldata(param_15, _53)
                                /// @src 20:1764:1921  "IPSwapAggregator(inp.pendleSwap).swap{..."
                                if iszero(extcodesize(_55))
                                {
                                    /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                                    revert(0, 0)
                                }
                                /// @src 20:1764:1921  "IPSwapAggregator(inp.pendleSwap).swap{..."
                                let _56 := /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(64)
                                /// @src 20:1764:1921  "IPSwapAggregator(inp.pendleSwap).swap{..."
                                mstore(_56, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ shl(226, 0x0af6e08f))
                                /// @src 20:1764:1921  "IPSwapAggregator(inp.pendleSwap).swap{..."
                                let _57 := call(gas(), _55, expr_21, _56, sub(abi_encode_address_uint256_struct_SwapData_calldata(add(_56, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 4), /** @src 20:1764:1921  "IPSwapAggregator(inp.pendleSwap).swap{..." */ expr_22, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ calldataload(/** @src 20:1896:1910  "inp.netTokenIn" */ add(param_15, /** @src 19:2083:2104  "IPYieldToken(YT).SY()" */ _50)), /** @src 20:1764:1921  "IPSwapAggregator(inp.pendleSwap).swap{..." */ expr_offset_1), _56), _56, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0)
                                /// @src 20:1764:1921  "IPSwapAggregator(inp.pendleSwap).swap{..."
                                if iszero(_57)
                                {
                                    /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                                    let pos_9 := mload(64)
                                    returndatacopy(pos_9, 0, returndatasize())
                                    revert(pos_9, returndatasize())
                                }
                                /// @src 20:1764:1921  "IPSwapAggregator(inp.pendleSwap).swap{..."
                                if _57
                                {
                                    finalize_allocation_8341(_56)
                                    /// @src 6:352:362  "address(0)"
                                    var_minSyOut := /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0
                                }
                                /// @src 20:1935:1981  "netTokenMintSy = _selfBalance(inp.tokenMintSy)"
                                var_netTokenMintSy_1 := /** @src 20:1952:1981  "_selfBalance(inp.tokenMintSy)" */ fun_selfBalance(/** @src 20:1965:1980  "inp.tokenMintSy" */ read_from_calldatat_address(add(param_15, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 64)))
                            }
                            default /// @src 20:1325:1992  "if (swapType == SwapType.ETH_WETH) {..."
                            {
                                /// @src 20:1386:1397  "inp.tokenIn"
                                let expr_23 := read_from_calldatat_address(param_15)
                                /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                                let value_6 := calldataload(/** @src 20:1411:1425  "inp.netTokenIn" */ add(param_15, /** @src 19:2083:2104  "IPYieldToken(YT).SY()" */ _50))
                                /// @src 20:1411:1425  "inp.netTokenIn"
                                fun_transferIn(expr_23, /** @src 20:1399:1409  "msg.sender" */ caller(), /** @src 20:1411:1425  "inp.netTokenIn" */ value_6)
                                /// @src 20:1457:1468  "inp.tokenIn"
                                let expr_24 := read_from_calldatat_address(param_15)
                                /// @src 20:1487:1501  "inp.netTokenIn"
                                fun_wrap_unwrap_ETH(expr_24, /** @src 20:1470:1485  "inp.tokenMintSy" */ read_from_calldatat_address(add(param_15, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 64)), /** @src 20:1487:1501  "inp.netTokenIn" */ value_6)
                                /// @src 20:1516:1547  "netTokenMintSy = inp.netTokenIn"
                                var_netTokenMintSy_1 := value_6
                            }
                        }
                        default /// @src 20:1166:1992  "if (swapType == SwapType.NONE) {..."
                        {
                            /// @src 20:1223:1234  "inp.tokenIn"
                            let expr_25 := read_from_calldatat_address(param_15)
                            /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                            let value_7 := calldataload(/** @src 20:1248:1262  "inp.netTokenIn" */ add(param_15, /** @src 19:2083:2104  "IPYieldToken(YT).SY()" */ _50))
                            /// @src 20:1248:1262  "inp.netTokenIn"
                            fun_transferIn(expr_25, /** @src 20:1236:1246  "msg.sender" */ caller(), /** @src 20:1248:1262  "inp.netTokenIn" */ value_7)
                            /// @src 20:1277:1308  "netTokenMintSy = inp.netTokenIn"
                            var_netTokenMintSy_1 := value_7
                        }
                        /// @src 20:2453:2468  "inp.tokenMintSy"
                        let _58 := add(param_15, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 64)
                        /// @src 20:2453:2478  "inp.tokenMintSy == NATIVE"
                        let expr_26 := iszero(/** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ and(/** @src 20:2453:2468  "inp.tokenMintSy" */ read_from_calldatat_address(_58), /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _47))
                        /// @src 20:2453:2499  "inp.tokenMintSy == NATIVE ? netTokenMintSy : 0"
                        let expr_27 := var_minSyOut
                        switch expr_26
                        case 0 { expr_27 := var_minSyOut }
                        default {
                            expr_27 := var_netTokenMintSy_1
                        }
                        /// @src 20:2514:2522  "inp.bulk"
                        let _59 := add(param_15, 96)
                        /// @src 20:2510:2957  "if (inp.bulk != address(0)) {..."
                        switch /** @src 20:2514:2536  "inp.bulk != address(0)" */ iszero(iszero(/** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ and(/** @src 20:2514:2522  "inp.bulk" */ read_from_calldatat_address(_59), /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _47)))
                        case /** @src 20:2510:2957  "if (inp.bulk != address(0)) {..." */ 0 {
                            /// @src 20:2859:2874  "inp.tokenMintSy"
                            let expr_28 := read_from_calldatat_address(_58)
                            /// @src 20:2765:2946  "IStandardizedYield(SY).deposit{ value: netNative }(..."
                            let _60 := /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(64)
                            /// @src 20:2765:2946  "IStandardizedYield(SY).deposit{ value: netNative }(..."
                            mstore(_60, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ shl(224, 0x20e8c565))
                            mstore(/** @src 20:2765:2946  "IStandardizedYield(SY).deposit{ value: netNative }(..." */ add(_60, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 4), _48)
                            mstore(add(/** @src 20:2765:2946  "IStandardizedYield(SY).deposit{ value: netNative }(..." */ _60, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 36), and(expr_28, _47))
                            mstore(add(/** @src 20:2765:2946  "IStandardizedYield(SY).deposit{ value: netNative }(..." */ _60, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 68), var_netTokenMintSy_1)
                            mstore(add(/** @src 20:2765:2946  "IStandardizedYield(SY).deposit{ value: netNative }(..." */ _60, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 100), var_minSyOut)
                            /// @src 20:2765:2946  "IStandardizedYield(SY).deposit{ value: netNative }(..."
                            let _61 := call(gas(), /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ and(/** @src 20:2765:2787  "IStandardizedYield(SY)" */ expr_18, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _47), /** @src 20:2765:2946  "IStandardizedYield(SY).deposit{ value: netNative }(..." */ expr_27, _60, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 132, /** @src 20:2765:2946  "IStandardizedYield(SY).deposit{ value: netNative }(..." */ _60, /** @src 19:2083:2104  "IPYieldToken(YT).SY()" */ _50)
                            /// @src 20:2765:2946  "IStandardizedYield(SY).deposit{ value: netNative }(..."
                            if iszero(_61)
                            {
                                /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                                let pos_10 := mload(64)
                                returndatacopy(pos_10, /** @src 20:1105:1122  "inp.data.swapType" */ var_minSyOut, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ returndatasize())
                                revert(pos_10, returndatasize())
                            }
                            /// @src 20:2765:2946  "IStandardizedYield(SY).deposit{ value: netNative }(..."
                            if _61
                            {
                                let _62 := /** @src 19:2083:2104  "IPYieldToken(YT).SY()" */ _50
                                /// @src 20:2765:2946  "IStandardizedYield(SY).deposit{ value: netNative }(..."
                                if gt(/** @src 19:2083:2104  "IPYieldToken(YT).SY()" */ _50, /** @src 20:2765:2946  "IStandardizedYield(SY).deposit{ value: netNative }(..." */ returndatasize()) { _62 := returndatasize() }
                                finalize_allocation(_60, _62)
                                /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                                if slt(sub(/** @src 20:2765:2946  "IStandardizedYield(SY).deposit{ value: netNative }(..." */ add(_60, _62), /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _60), /** @src 19:2083:2104  "IPYieldToken(YT).SY()" */ _50)
                                /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                                { revert(0, 0) }
                            }
                        }
                        default /// @src 20:2510:2957  "if (inp.bulk != address(0)) {..."
                        {
                            /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                            let _63 := and(/** @src 20:2576:2584  "inp.bulk" */ read_from_calldatat_address(_59), /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _47)
                            /// @src 20:2563:2723  "IPBulkSeller(inp.bulk).swapExactTokenForSy{ value: netNative }(..."
                            let _64 := /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(64)
                            /// @src 20:2563:2723  "IPBulkSeller(inp.bulk).swapExactTokenForSy{ value: netNative }(..."
                            mstore(_64, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ shl(228, 0x0b276707))
                            /// @src 20:2563:2723  "IPBulkSeller(inp.bulk).swapExactTokenForSy{ value: netNative }(..."
                            let _65 := call(gas(), _63, expr_27, _64, sub(abi_encode_address_uint256_uint256(add(_64, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 4), /** @src 20:2563:2723  "IPBulkSeller(inp.bulk).swapExactTokenForSy{ value: netNative }(..." */ param_13, var_netTokenMintSy_1, var_minSyOut), _64), _64, /** @src 19:2083:2104  "IPYieldToken(YT).SY()" */ _50)
                            /// @src 20:2563:2723  "IPBulkSeller(inp.bulk).swapExactTokenForSy{ value: netNative }(..."
                            if iszero(_65)
                            {
                                /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                                let pos_11 := mload(64)
                                returndatacopy(pos_11, /** @src 20:1105:1122  "inp.data.swapType" */ var_minSyOut, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ returndatasize())
                                revert(pos_11, returndatasize())
                            }
                            /// @src 20:2563:2723  "IPBulkSeller(inp.bulk).swapExactTokenForSy{ value: netNative }(..."
                            if _65
                            {
                                let _66 := /** @src 19:2083:2104  "IPYieldToken(YT).SY()" */ _50
                                /// @src 20:2563:2723  "IPBulkSeller(inp.bulk).swapExactTokenForSy{ value: netNative }(..."
                                if gt(/** @src 19:2083:2104  "IPYieldToken(YT).SY()" */ _50, /** @src 20:2563:2723  "IPBulkSeller(inp.bulk).swapExactTokenForSy{ value: netNative }(..." */ returndatasize()) { _66 := returndatasize() }
                                finalize_allocation(_64, _66)
                                /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                                if slt(sub(/** @src 20:2563:2723  "IPBulkSeller(inp.bulk).swapExactTokenForSy{ value: netNative }(..." */ add(_64, _66), /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _64), /** @src 19:2083:2104  "IPYieldToken(YT).SY()" */ _50)
                                /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                                { revert(0, 0) }
                            }
                        }
                        /// @src 20:5283:5326  "IPYieldToken(YT).mintPY(receiver, receiver)"
                        let _67 := /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(64)
                        /// @src 20:5283:5326  "IPYieldToken(YT).mintPY(receiver, receiver)"
                        mstore(_67, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ shl(224, 0xdb74aa15))
                        let _68 := and(param_12, _47)
                        mstore(/** @src 20:5283:5326  "IPYieldToken(YT).mintPY(receiver, receiver)" */ add(_67, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 4), _68)
                        mstore(add(/** @src 20:5283:5326  "IPYieldToken(YT).mintPY(receiver, receiver)" */ _67, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 36), _68)
                        /// @src 20:5283:5326  "IPYieldToken(YT).mintPY(receiver, receiver)"
                        let _69 := call(gas(), _48, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0, /** @src 20:5283:5326  "IPYieldToken(YT).mintPY(receiver, receiver)" */ _67, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 68, /** @src 20:5283:5326  "IPYieldToken(YT).mintPY(receiver, receiver)" */ _67, /** @src 19:2083:2104  "IPYieldToken(YT).SY()" */ _50)
                        /// @src 20:5283:5326  "IPYieldToken(YT).mintPY(receiver, receiver)"
                        if iszero(_69)
                        {
                            /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                            let pos_12 := mload(64)
                            returndatacopy(pos_12, 0, returndatasize())
                            revert(pos_12, returndatasize())
                        }
                        /// @src 20:5283:5326  "IPYieldToken(YT).mintPY(receiver, receiver)"
                        let expr_29 := /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0
                        /// @src 20:5283:5326  "IPYieldToken(YT).mintPY(receiver, receiver)"
                        if _69
                        {
                            let _70 := /** @src 19:2083:2104  "IPYieldToken(YT).SY()" */ _50
                            /// @src 20:5283:5326  "IPYieldToken(YT).mintPY(receiver, receiver)"
                            if gt(/** @src 19:2083:2104  "IPYieldToken(YT).SY()" */ _50, /** @src 20:5283:5326  "IPYieldToken(YT).mintPY(receiver, receiver)" */ returndatasize()) { _70 := returndatasize() }
                            finalize_allocation(_67, _70)
                            /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                            if slt(sub(/** @src 20:5283:5326  "IPYieldToken(YT).mintPY(receiver, receiver)" */ add(_67, _70), /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _67), /** @src 19:2083:2104  "IPYieldToken(YT).SY()" */ _50)
                            /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                            { revert(0, 0) }
                            /// @src 20:5283:5326  "IPYieldToken(YT).mintPY(receiver, receiver)"
                            expr_29 := /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(_67)
                        }
                        /// @src 20:5336:5418  "if (netPyOut < minPyOut) revert Errors.RouterInsufficientPYOut(netPyOut, minPyOut)"
                        if /** @src 20:5340:5359  "netPyOut < minPyOut" */ lt(expr_29, param_14)
                        /// @src 20:5336:5418  "if (netPyOut < minPyOut) revert Errors.RouterInsufficientPYOut(netPyOut, minPyOut)"
                        {
                            /// @src 20:5368:5418  "Errors.RouterInsufficientPYOut(netPyOut, minPyOut)"
                            let _71 := /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(64)
                            /// @src 20:5368:5418  "Errors.RouterInsufficientPYOut(netPyOut, minPyOut)"
                            mstore(_71, shl(224, 0xca935dfd))
                            /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                            mstore(/** @src 20:5368:5418  "Errors.RouterInsufficientPYOut(netPyOut, minPyOut)" */ add(_71, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 4), expr_29)
                            mstore(add(/** @src 20:5368:5418  "Errors.RouterInsufficientPYOut(netPyOut, minPyOut)" */ _71, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 36), param_14)
                            /// @src 20:5368:5418  "Errors.RouterInsufficientPYOut(netPyOut, minPyOut)"
                            revert(_71, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 68)
                        }
                        /// @src 19:2297:2310  "input.tokenIn"
                        let expr_30 := read_from_calldatat_address(param_15)
                        /// @src 19:2269:2353  "MintPyFromToken(msg.sender, input.tokenIn, YT, receiver, input.netTokenIn, netPyOut)"
                        let _72 := /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(64)
                        /// @src 19:2269:2353  "MintPyFromToken(msg.sender, input.tokenIn, YT, receiver, input.netTokenIn, netPyOut)"
                        log4(_72, sub(abi_encode_address_uint256_uint256(_72, param_12, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ calldataload(/** @src 19:2326:2342  "input.netTokenIn" */ add(param_15, /** @src 19:2083:2104  "IPYieldToken(YT).SY()" */ _50)), /** @src 19:2269:2353  "MintPyFromToken(msg.sender, input.tokenIn, YT, receiver, input.netTokenIn, netPyOut)" */ expr_29), _72), 0xf586e656e1e436d9ca7c96e43cb793e47b685467d5d574a66efabb8501a333b8, /** @src 19:2285:2295  "msg.sender" */ caller(), /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ and(/** @src 19:2269:2353  "MintPyFromToken(msg.sender, input.tokenIn, YT, receiver, input.netTokenIn, netPyOut)" */ expr_30, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _47), /** @src 19:2269:2353  "MintPyFromToken(msg.sender, input.tokenIn, YT, receiver, input.netTokenIn, netPyOut)" */ _48)
                        /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                        let memPos_3 := mload(64)
                        mstore(memPos_3, expr_29)
                        return(memPos_3, /** @src 19:2083:2104  "IPYieldToken(YT).SY()" */ _50)
                    }
                    case /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0x527df199 {
                        if callvalue() { revert(0, 0) }
                        let param_16, param_17, param_18, param_19 := abi_decode_addresst_addresst_uint256t_struct_TokenInput_calldata(calldatasize())
                        let _73 := sub(shl(160, 1), 1)
                        let _74 := and(/** @src 19:2854:2870  "IPYieldToken(YT)" */ param_17, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _73)
                        /// @src 19:2854:2875  "IPYieldToken(YT).SY()"
                        let _75 := /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(64)
                        /// @src 19:2854:2875  "IPYieldToken(YT).SY()"
                        mstore(_75, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ shl(224, 0xafd27bf5))
                        /// @src 19:2854:2875  "IPYieldToken(YT).SY()"
                        let _76 := 32
                        let _77 := staticcall(gas(), _74, _75, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 4, /** @src 19:2854:2875  "IPYieldToken(YT).SY()" */ _75, _76)
                        if iszero(_77)
                        {
                            /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                            let pos_13 := mload(64)
                            returndatacopy(pos_13, 0, returndatasize())
                            revert(pos_13, returndatasize())
                        }
                        /// @src 19:2854:2875  "IPYieldToken(YT).SY()"
                        let expr_31 := /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0
                        /// @src 19:2854:2875  "IPYieldToken(YT).SY()"
                        if _77
                        {
                            let _78 := _76
                            if gt(_76, returndatasize()) { _78 := returndatasize() }
                            finalize_allocation(_75, _78)
                            expr_31 := abi_decode_address_fromMemory(_75, add(_75, _78))
                        }
                        /// @src 19:2924:2945  "_syOrBulk(SY, output)"
                        let _79 := fun_syOrBulk(expr_31, param_19)
                        /// @src 20:5616:5637  "IPYieldToken(YT).PT()"
                        let _80 := /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(64)
                        /// @src 20:5616:5637  "IPYieldToken(YT).PT()"
                        mstore(_80, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ shl(226, 0x36501cf5))
                        /// @src 20:5616:5637  "IPYieldToken(YT).PT()"
                        let _81 := staticcall(gas(), _74, _80, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 4, /** @src 20:5616:5637  "IPYieldToken(YT).PT()" */ _80, /** @src 19:2854:2875  "IPYieldToken(YT).SY()" */ _76)
                        /// @src 20:5616:5637  "IPYieldToken(YT).PT()"
                        if iszero(_81)
                        {
                            /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                            let pos_14 := mload(64)
                            returndatacopy(pos_14, 0, returndatasize())
                            revert(pos_14, returndatasize())
                        }
                        /// @src 20:5616:5637  "IPYieldToken(YT).PT()"
                        let expr_32 := /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0
                        /// @src 20:5616:5637  "IPYieldToken(YT).PT()"
                        if _81
                        {
                            let _82 := /** @src 19:2854:2875  "IPYieldToken(YT).SY()" */ _76
                            /// @src 20:5616:5637  "IPYieldToken(YT).PT()"
                            if gt(/** @src 19:2854:2875  "IPYieldToken(YT).SY()" */ _76, /** @src 20:5616:5637  "IPYieldToken(YT).PT()" */ returndatasize()) { _82 := returndatasize() }
                            finalize_allocation(_80, _82)
                            expr_32 := abi_decode_address_fromMemory(_80, add(_80, _82))
                        }
                        /// @src 6:908:919  "amount != 0"
                        let _83 := iszero(iszero(param_18))
                        /// @src 6:904:961  "if (amount != 0) token.safeTransferFrom(from, to, amount)"
                        if /** @src 6:908:919  "amount != 0" */ _83
                        /// @src 6:904:961  "if (amount != 0) token.safeTransferFrom(from, to, amount)"
                        {
                            /// @src 6:954:960  "amount"
                            fun_safeTransferFrom(/** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ and(/** @src 20:5662:5672  "IERC20(PT)" */ expr_32, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _73), /** @src 20:5674:5684  "msg.sender" */ caller(), /** @src 6:954:960  "amount" */ param_17, param_18)
                        }
                        /// @src 20:5731:5759  "IPYieldToken(YT).isExpired()"
                        let _84 := /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(64)
                        /// @src 20:5731:5759  "IPYieldToken(YT).isExpired()"
                        mstore(_84, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ shl(226, 0x0bc4ed83))
                        /// @src 20:5731:5759  "IPYieldToken(YT).isExpired()"
                        let _85 := staticcall(gas(), _74, _84, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 4, /** @src 20:5731:5759  "IPYieldToken(YT).isExpired()" */ _84, /** @src 19:2854:2875  "IPYieldToken(YT).SY()" */ _76)
                        /// @src 20:5731:5759  "IPYieldToken(YT).isExpired()"
                        if iszero(_85)
                        {
                            /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                            let pos_15 := mload(64)
                            returndatacopy(pos_15, 0, returndatasize())
                            revert(pos_15, returndatasize())
                        }
                        /// @src 20:5731:5759  "IPYieldToken(YT).isExpired()"
                        let expr_33 := /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0
                        /// @src 20:5731:5759  "IPYieldToken(YT).isExpired()"
                        if _85
                        {
                            let _86 := /** @src 19:2854:2875  "IPYieldToken(YT).SY()" */ _76
                            /// @src 20:5731:5759  "IPYieldToken(YT).isExpired()"
                            if gt(/** @src 19:2854:2875  "IPYieldToken(YT).SY()" */ _76, /** @src 20:5731:5759  "IPYieldToken(YT).isExpired()" */ returndatasize()) { _86 := returndatasize() }
                            finalize_allocation(_84, _86)
                            expr_33 := abi_decode_bool_fromMemory(_84, add(_84, _86))
                        }
                        /// @src 20:5770:5838  "if (needToBurnYt) _transferFrom(IERC20(YT), msg.sender, YT, netPyIn)"
                        if /** @src 20:5730:5759  "!IPYieldToken(YT).isExpired()" */ iszero(expr_33)
                        /// @src 20:5770:5838  "if (needToBurnYt) _transferFrom(IERC20(YT), msg.sender, YT, netPyIn)"
                        {
                            /// @src 6:904:961  "if (amount != 0) token.safeTransferFrom(from, to, amount)"
                            if /** @src 6:908:919  "amount != 0" */ _83
                            /// @src 6:904:961  "if (amount != 0) token.safeTransferFrom(from, to, amount)"
                            {
                                /// @src 6:954:960  "amount"
                                fun_safeTransferFrom(_74, /** @src 20:5674:5684  "msg.sender" */ caller(), /** @src 6:954:960  "amount" */ param_17, param_18)
                            }
                        }
                        /// @src 20:5860:5895  "IPYieldToken(YT).redeemPY(receiver)"
                        let _87 := /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(64)
                        /// @src 20:5860:5895  "IPYieldToken(YT).redeemPY(receiver)"
                        mstore(_87, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ shl(224, 0xbcb7ea5d))
                        mstore(/** @src 20:5860:5895  "IPYieldToken(YT).redeemPY(receiver)" */ add(_87, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 4), and(_79, _73))
                        /// @src 20:5860:5895  "IPYieldToken(YT).redeemPY(receiver)"
                        let _88 := call(gas(), _74, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0, /** @src 20:5860:5895  "IPYieldToken(YT).redeemPY(receiver)" */ _87, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 36, /** @src 20:5860:5895  "IPYieldToken(YT).redeemPY(receiver)" */ _87, /** @src 19:2854:2875  "IPYieldToken(YT).SY()" */ _76)
                        /// @src 20:5860:5895  "IPYieldToken(YT).redeemPY(receiver)"
                        if iszero(_88)
                        {
                            /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                            let pos_16 := mload(64)
                            returndatacopy(pos_16, 0, returndatasize())
                            revert(pos_16, returndatasize())
                        }
                        /// @src 20:5860:5895  "IPYieldToken(YT).redeemPY(receiver)"
                        let expr_34 := /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0
                        /// @src 20:5860:5895  "IPYieldToken(YT).redeemPY(receiver)"
                        if _88
                        {
                            let _89 := /** @src 19:2854:2875  "IPYieldToken(YT).SY()" */ _76
                            /// @src 20:5860:5895  "IPYieldToken(YT).redeemPY(receiver)"
                            if gt(/** @src 19:2854:2875  "IPYieldToken(YT).SY()" */ _76, /** @src 20:5860:5895  "IPYieldToken(YT).redeemPY(receiver)" */ returndatasize()) { _89 := returndatasize() }
                            finalize_allocation(_87, _89)
                            /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                            if slt(sub(/** @src 20:5860:5895  "IPYieldToken(YT).redeemPY(receiver)" */ add(_87, _89), /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _87), /** @src 19:2854:2875  "IPYieldToken(YT).SY()" */ _76)
                            /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                            { revert(0, 0) }
                            /// @src 20:5860:5895  "IPYieldToken(YT).redeemPY(receiver)"
                            expr_34 := /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(_87)
                        }
                        /// @src 20:5905:5987  "if (netSyOut < minSyOut) revert Errors.RouterInsufficientSyOut(netSyOut, minSyOut)"
                        if /** @src 20:5909:5928  "netSyOut < minSyOut" */ lt(expr_34, /** @src 19:2960:2961  "1" */ 0x01)
                        /// @src 20:5905:5987  "if (netSyOut < minSyOut) revert Errors.RouterInsufficientSyOut(netSyOut, minSyOut)"
                        {
                            /// @src 20:5937:5987  "Errors.RouterInsufficientSyOut(netSyOut, minSyOut)"
                            let _90 := /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(64)
                            /// @src 20:5937:5987  "Errors.RouterInsufficientSyOut(netSyOut, minSyOut)"
                            mstore(_90, shl(225, 0x05221cf3))
                            /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                            mstore(/** @src 20:5937:5987  "Errors.RouterInsufficientSyOut(netSyOut, minSyOut)" */ add(_90, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 4), expr_34)
                            mstore(add(/** @src 20:5937:5987  "Errors.RouterInsufficientSyOut(netSyOut, minSyOut)" */ _90, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 36), /** @src 19:2960:2961  "1" */ 0x01)
                            /// @src 20:5937:5987  "Errors.RouterInsufficientSyOut(netSyOut, minSyOut)"
                            revert(_90, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 68)
                        }
                        /// @src 19:2986:3046  "_redeemSyToToken(receiver, SY, netSyToRedeem, output, false)"
                        let var_netTokenOut := /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0
                        /// @src 20:3196:3204  "out.data"
                        let _91 := add(param_19, 160)
                        /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                        let value_8 := calldataload(/** @src 20:3196:3204  "out.data" */ access_calldata_tail_struct_SwapData_calldata(param_19, _91))
                        /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                        if iszero(lt(value_8, 4)) { revert(0, 0) }
                        /// @src 20:3224:3959  "if (swapType == SwapType.NONE) {..."
                        switch /** @src 20:3228:3253  "swapType == SwapType.NONE" */ iszero(value_8)
                        case /** @src 20:3224:3959  "if (swapType == SwapType.NONE) {..." */ 0 {
                            /// @src 20:3346:3959  "if (swapType == SwapType.ETH_WETH) {..."
                            switch /** @src 20:3350:3379  "swapType == SwapType.ETH_WETH" */ eq(value_8, /** @src 20:3362:3379  "SwapType.ETH_WETH" */ 3)
                            case /** @src 20:3346:3959  "if (swapType == SwapType.ETH_WETH) {..." */ 0 {
                                /// @src 20:3689:3703  "out.pendleSwap"
                                let _92 := add(param_19, 128)
                                /// @src 20:3678:3730  "__redeemSy(out.pendleSwap, SY, netSyIn, out, doPull)"
                                let expr_35 := fun_redeemSy(/** @src 20:3689:3703  "out.pendleSwap" */ read_from_calldatat_address(_92), /** @src 20:3678:3730  "__redeemSy(out.pendleSwap, SY, netSyIn, out, doPull)" */ expr_31, expr_34, param_19)
                                /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                                let _93 := and(/** @src 20:3762:3776  "out.pendleSwap" */ read_from_calldatat_address(_92), /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _73)
                                /// @src 20:3783:3800  "out.tokenRedeemSy"
                                let expr_36 := read_from_calldatat_address(add(param_19, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 64))
                                /// @src 20:3820:3828  "out.data"
                                let expr_offset_2 := access_calldata_tail_struct_SwapData_calldata(param_19, _91)
                                /// @src 20:3745:3829  "IPSwapAggregator(out.pendleSwap).swap(out.tokenRedeemSy, netTokenRedeemed, out.data)"
                                if iszero(extcodesize(_93))
                                {
                                    /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                                    revert(0, 0)
                                }
                                /// @src 20:3745:3829  "IPSwapAggregator(out.pendleSwap).swap(out.tokenRedeemSy, netTokenRedeemed, out.data)"
                                let _94 := /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(64)
                                /// @src 20:3745:3829  "IPSwapAggregator(out.pendleSwap).swap(out.tokenRedeemSy, netTokenRedeemed, out.data)"
                                mstore(_94, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ shl(226, 0x0af6e08f))
                                /// @src 20:3745:3829  "IPSwapAggregator(out.pendleSwap).swap(out.tokenRedeemSy, netTokenRedeemed, out.data)"
                                let _95 := call(gas(), _93, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0, /** @src 20:3745:3829  "IPSwapAggregator(out.pendleSwap).swap(out.tokenRedeemSy, netTokenRedeemed, out.data)" */ _94, sub(abi_encode_address_uint256_struct_SwapData_calldata(add(_94, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 4), /** @src 20:3745:3829  "IPSwapAggregator(out.pendleSwap).swap(out.tokenRedeemSy, netTokenRedeemed, out.data)" */ expr_36, expr_35, expr_offset_2), _94), _94, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0)
                                /// @src 20:3745:3829  "IPSwapAggregator(out.pendleSwap).swap(out.tokenRedeemSy, netTokenRedeemed, out.data)"
                                if iszero(_95)
                                {
                                    /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                                    let pos_17 := mload(64)
                                    returndatacopy(pos_17, 0, returndatasize())
                                    revert(pos_17, returndatasize())
                                }
                                /// @src 20:3745:3829  "IPSwapAggregator(out.pendleSwap).swap(out.tokenRedeemSy, netTokenRedeemed, out.data)"
                                if _95 { finalize_allocation_8341(_94) }
                                /// @src 20:3844:3884  "netTokenOut = _selfBalance(out.tokenOut)"
                                var_netTokenOut := /** @src 20:3858:3884  "_selfBalance(out.tokenOut)" */ fun_selfBalance(/** @src 20:3871:3883  "out.tokenOut" */ read_from_calldatat_address(param_19))
                                /// @src 20:3936:3947  "netTokenOut"
                                fun_transferOut(/** @src 20:3912:3924  "out.tokenOut" */ read_from_calldatat_address(param_19), /** @src 20:3936:3947  "netTokenOut" */ param_16, var_netTokenOut)
                            }
                            default /// @src 20:3346:3959  "if (swapType == SwapType.ETH_WETH) {..."
                            {
                                /// @src 20:3395:3460  "netTokenOut = __redeemSy(address(this), SY, netSyIn, out, doPull)"
                                var_netTokenOut := /** @src 20:3409:3460  "__redeemSy(address(this), SY, netSyIn, out, doPull)" */ fun_redeemSy(/** @src 20:3428:3432  "this" */ address(), /** @src 20:3409:3460  "__redeemSy(address(this), SY, netSyIn, out, doPull)" */ expr_31, expr_34, param_19)
                                /// @src 20:3511:3528  "out.tokenRedeemSy"
                                let expr_37 := read_from_calldatat_address(add(param_19, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 64))
                                /// @src 20:3544:3555  "netTokenOut"
                                fun_wrap_unwrap_ETH(expr_37, /** @src 20:3530:3542  "out.tokenOut" */ read_from_calldatat_address(param_19), /** @src 20:3544:3555  "netTokenOut" */ var_netTokenOut)
                                /// @src 20:3608:3619  "netTokenOut"
                                fun_transferOut(/** @src 20:3584:3596  "out.tokenOut" */ read_from_calldatat_address(param_19), /** @src 20:3608:3619  "netTokenOut" */ param_16, var_netTokenOut)
                            }
                        }
                        default /// @src 20:3224:3959  "if (swapType == SwapType.NONE) {..."
                        {
                            /// @src 20:3269:3329  "netTokenOut = __redeemSy(receiver, SY, netSyIn, out, doPull)"
                            var_netTokenOut := /** @src 20:3283:3329  "__redeemSy(receiver, SY, netSyIn, out, doPull)" */ fun_redeemSy(param_16, expr_31, expr_34, param_19)
                        }
                        /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                        let value_9 := calldataload(/** @src 20:4068:4083  "out.minTokenOut" */ add(param_19, /** @src 19:2854:2875  "IPYieldToken(YT).SY()" */ _76))
                        /// @src 20:4050:4180  "if (netTokenOut < out.minTokenOut) {..."
                        if /** @src 20:4054:4083  "netTokenOut < out.minTokenOut" */ lt(var_netTokenOut, value_9)
                        /// @src 20:4050:4180  "if (netTokenOut < out.minTokenOut) {..."
                        {
                            /// @src 20:4106:4169  "Errors.RouterInsufficientTokenOut(netTokenOut, out.minTokenOut)"
                            let _96 := /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(64)
                            /// @src 20:4106:4169  "Errors.RouterInsufficientTokenOut(netTokenOut, out.minTokenOut)"
                            mstore(_96, shl(224, 0xc5b5576d))
                            /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                            mstore(/** @src 20:4106:4169  "Errors.RouterInsufficientTokenOut(netTokenOut, out.minTokenOut)" */ add(_96, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 4), var_netTokenOut)
                            mstore(add(/** @src 20:4106:4169  "Errors.RouterInsufficientTokenOut(netTokenOut, out.minTokenOut)" */ _96, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 36), value_9)
                            /// @src 20:4106:4169  "Errors.RouterInsufficientTokenOut(netTokenOut, out.minTokenOut)"
                            revert(_96, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 68)
                        }
                        let _97 := and(/** @src 19:3090:3105  "output.tokenOut" */ read_from_calldatat_address(param_19), /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _73)
                        /// @src 19:3062:3142  "RedeemPyToToken(msg.sender, output.tokenOut, YT, receiver, netPyIn, netTokenOut)"
                        let _98 := /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(64)
                        /// @src 19:3062:3142  "RedeemPyToToken(msg.sender, output.tokenOut, YT, receiver, netPyIn, netTokenOut)"
                        log4(_98, sub(abi_encode_address_uint256_uint256(_98, param_16, param_18, var_netTokenOut), _98), 0xbc9f07701b0532bc31f2fe7a59b23aa94ae7e58ae26437b01b3440c5903b1bf1, /** @src 20:5674:5684  "msg.sender" */ caller(), /** @src 19:3062:3142  "RedeemPyToToken(msg.sender, output.tokenOut, YT, receiver, netPyIn, netTokenOut)" */ _97, _74)
                        /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                        let memPos_4 := mload(64)
                        mstore(memPos_4, var_netTokenOut)
                        return(memPos_4, /** @src 19:2854:2875  "IPYieldToken(YT).SY()" */ _76)
                    }
                    case /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0x85b29936 {
                        if callvalue() { revert(0, 0) }
                        let param_20, param_21, param_22, param_23 := abi_decode_addresst_addresst_uint256t_struct_TokenInput_calldata(calldatasize())
                        /// @src 19:1413:1466  "_redeemSyToToken(receiver, SY, netSyIn, output, true)"
                        let var_netTokenOut_1 := /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0
                        /// @src 20:3196:3204  "out.data"
                        let _99 := add(param_23, 160)
                        /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                        let value_10 := calldataload(/** @src 20:3196:3204  "out.data" */ access_calldata_tail_struct_SwapData_calldata(param_23, _99))
                        /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                        if iszero(lt(value_10, 4)) { revert(0, 0) }
                        /// @src 20:3224:3959  "if (swapType == SwapType.NONE) {..."
                        switch /** @src 20:3228:3253  "swapType == SwapType.NONE" */ iszero(value_10)
                        case /** @src 20:3224:3959  "if (swapType == SwapType.NONE) {..." */ 0 {
                            /// @src 20:3346:3959  "if (swapType == SwapType.ETH_WETH) {..."
                            switch /** @src 20:3350:3379  "swapType == SwapType.ETH_WETH" */ eq(value_10, /** @src 20:3362:3379  "SwapType.ETH_WETH" */ 3)
                            case /** @src 20:3346:3959  "if (swapType == SwapType.ETH_WETH) {..." */ 0 {
                                /// @src 20:3689:3703  "out.pendleSwap"
                                let _100 := add(param_23, 128)
                                /// @src 20:3678:3730  "__redeemSy(out.pendleSwap, SY, netSyIn, out, doPull)"
                                let expr_38 := fun__redeemSy(/** @src 20:3689:3703  "out.pendleSwap" */ read_from_calldatat_address(_100), /** @src 20:3678:3730  "__redeemSy(out.pendleSwap, SY, netSyIn, out, doPull)" */ param_21, param_22, param_23)
                                /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                                let _101 := and(/** @src 20:3762:3776  "out.pendleSwap" */ read_from_calldatat_address(_100), /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ sub(shl(160, 1), 1))
                                /// @src 20:3783:3800  "out.tokenRedeemSy"
                                let expr_39 := read_from_calldatat_address(add(param_23, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 64))
                                /// @src 20:3820:3828  "out.data"
                                let expr_offset_3 := access_calldata_tail_struct_SwapData_calldata(param_23, _99)
                                /// @src 20:3745:3829  "IPSwapAggregator(out.pendleSwap).swap(out.tokenRedeemSy, netTokenRedeemed, out.data)"
                                if iszero(extcodesize(_101))
                                {
                                    /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                                    revert(0, 0)
                                }
                                /// @src 20:3745:3829  "IPSwapAggregator(out.pendleSwap).swap(out.tokenRedeemSy, netTokenRedeemed, out.data)"
                                let _102 := /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(64)
                                /// @src 20:3745:3829  "IPSwapAggregator(out.pendleSwap).swap(out.tokenRedeemSy, netTokenRedeemed, out.data)"
                                mstore(_102, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ shl(226, 0x0af6e08f))
                                /// @src 20:3745:3829  "IPSwapAggregator(out.pendleSwap).swap(out.tokenRedeemSy, netTokenRedeemed, out.data)"
                                let _103 := call(gas(), _101, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0, /** @src 20:3745:3829  "IPSwapAggregator(out.pendleSwap).swap(out.tokenRedeemSy, netTokenRedeemed, out.data)" */ _102, sub(abi_encode_address_uint256_struct_SwapData_calldata(add(_102, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 4), /** @src 20:3745:3829  "IPSwapAggregator(out.pendleSwap).swap(out.tokenRedeemSy, netTokenRedeemed, out.data)" */ expr_39, expr_38, expr_offset_3), _102), _102, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0)
                                /// @src 20:3745:3829  "IPSwapAggregator(out.pendleSwap).swap(out.tokenRedeemSy, netTokenRedeemed, out.data)"
                                if iszero(_103)
                                {
                                    /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                                    let pos_18 := mload(64)
                                    returndatacopy(pos_18, 0, returndatasize())
                                    revert(pos_18, returndatasize())
                                }
                                /// @src 20:3745:3829  "IPSwapAggregator(out.pendleSwap).swap(out.tokenRedeemSy, netTokenRedeemed, out.data)"
                                if _103
                                {
                                    finalize_allocation_8341(_102)
                                }
                                /// @src 20:3844:3884  "netTokenOut = _selfBalance(out.tokenOut)"
                                var_netTokenOut_1 := /** @src 20:3858:3884  "_selfBalance(out.tokenOut)" */ fun_selfBalance(/** @src 20:3871:3883  "out.tokenOut" */ read_from_calldatat_address(param_23))
                                /// @src 20:3936:3947  "netTokenOut"
                                fun_transferOut(/** @src 20:3912:3924  "out.tokenOut" */ read_from_calldatat_address(param_23), /** @src 20:3936:3947  "netTokenOut" */ param_20, var_netTokenOut_1)
                            }
                            default /// @src 20:3346:3959  "if (swapType == SwapType.ETH_WETH) {..."
                            {
                                /// @src 20:3395:3460  "netTokenOut = __redeemSy(address(this), SY, netSyIn, out, doPull)"
                                var_netTokenOut_1 := /** @src 20:3409:3460  "__redeemSy(address(this), SY, netSyIn, out, doPull)" */ fun__redeemSy(/** @src 20:3428:3432  "this" */ address(), /** @src 20:3409:3460  "__redeemSy(address(this), SY, netSyIn, out, doPull)" */ param_21, param_22, param_23)
                                /// @src 20:3511:3528  "out.tokenRedeemSy"
                                let expr_40 := read_from_calldatat_address(add(param_23, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 64))
                                /// @src 20:3544:3555  "netTokenOut"
                                fun_wrap_unwrap_ETH(expr_40, /** @src 20:3530:3542  "out.tokenOut" */ read_from_calldatat_address(param_23), /** @src 20:3544:3555  "netTokenOut" */ var_netTokenOut_1)
                                /// @src 20:3608:3619  "netTokenOut"
                                fun_transferOut(/** @src 20:3584:3596  "out.tokenOut" */ read_from_calldatat_address(param_23), /** @src 20:3608:3619  "netTokenOut" */ param_20, var_netTokenOut_1)
                            }
                        }
                        default /// @src 20:3224:3959  "if (swapType == SwapType.NONE) {..."
                        {
                            /// @src 20:3269:3329  "netTokenOut = __redeemSy(receiver, SY, netSyIn, out, doPull)"
                            var_netTokenOut_1 := /** @src 20:3283:3329  "__redeemSy(receiver, SY, netSyIn, out, doPull)" */ fun__redeemSy(param_20, param_21, param_22, param_23)
                        }
                        /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                        let value_11 := calldataload(/** @src 20:4068:4083  "out.minTokenOut" */ add(param_23, 32))
                        /// @src 20:4050:4180  "if (netTokenOut < out.minTokenOut) {..."
                        if /** @src 20:4054:4083  "netTokenOut < out.minTokenOut" */ lt(var_netTokenOut_1, value_11)
                        /// @src 20:4050:4180  "if (netTokenOut < out.minTokenOut) {..."
                        {
                            /// @src 20:4106:4169  "Errors.RouterInsufficientTokenOut(netTokenOut, out.minTokenOut)"
                            let _104 := /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(64)
                            /// @src 20:4106:4169  "Errors.RouterInsufficientTokenOut(netTokenOut, out.minTokenOut)"
                            mstore(_104, shl(224, 0xc5b5576d))
                            /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                            mstore(/** @src 20:4106:4169  "Errors.RouterInsufficientTokenOut(netTokenOut, out.minTokenOut)" */ add(_104, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 4), var_netTokenOut_1)
                            mstore(add(/** @src 20:4106:4169  "Errors.RouterInsufficientTokenOut(netTokenOut, out.minTokenOut)" */ _104, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 36), value_11)
                            /// @src 20:4106:4169  "Errors.RouterInsufficientTokenOut(netTokenOut, out.minTokenOut)"
                            revert(_104, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 68)
                        }
                        let _105 := sub(shl(160, 1), 1)
                        let _106 := and(/** @src 19:1509:1524  "output.tokenOut" */ read_from_calldatat_address(param_23), /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _105)
                        /// @src 19:1481:1561  "RedeemSyToToken(msg.sender, output.tokenOut, SY, receiver, netSyIn, netTokenOut)"
                        let _107 := /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(64)
                        /// @src 19:1481:1561  "RedeemSyToToken(msg.sender, output.tokenOut, SY, receiver, netSyIn, netTokenOut)"
                        log4(_107, sub(abi_encode_address_uint256_uint256(_107, param_20, param_22, var_netTokenOut_1), _107), 0xcd34b6ac7e4b72ab30845649aef2f4fd41945ae2dc08f625be69738bbd0f9aa9, /** @src 19:1497:1507  "msg.sender" */ caller(), /** @src 19:1481:1561  "RedeemSyToToken(msg.sender, output.tokenOut, SY, receiver, netSyIn, netTokenOut)" */ _106, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ and(/** @src 19:1481:1561  "RedeemSyToToken(msg.sender, output.tokenOut, SY, receiver, netSyIn, netTokenOut)" */ param_21, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _105))
                        let memPos_5 := mload(64)
                        mstore(memPos_5, var_netTokenOut_1)
                        return(memPos_5, /** @src 20:4068:4083  "out.minTokenOut" */ 32)
                    }
                    case /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0xf7e375e8 {
                        if callvalue() { revert(0, 0) }
                        if slt(add(calldatasize(), not(3)), 128) { revert(0, 0) }
                        let value_12 := calldataload(4)
                        if iszero(eq(value_12, and(value_12, sub(shl(160, 1), 1)))) { revert(0, 0) }
                        let offset := calldataload(36)
                        if gt(offset, 0xffffffffffffffff) { revert(0, 0) }
                        let value1, value2 := abi_decode_array_address_dyn_calldata(add(4, offset), calldatasize())
                        let offset_1 := calldataload(68)
                        if gt(offset_1, 0xffffffffffffffff) { revert(0, 0) }
                        let value3, value4 := abi_decode_array_address_dyn_calldata(add(4, offset_1), calldatasize())
                        let offset_2 := calldataload(100)
                        if gt(offset_2, 0xffffffffffffffff) { revert(0, 0) }
                        let value5, value6 := abi_decode_array_address_dyn_calldata(add(4, offset_2), calldatasize())
                        /// @src 19:4387:4400  "uint256 i = 0"
                        let var_i := /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0
                        /// @src 19:4382:4501  "for (uint256 i = 0; i < sys.length; ++i) {..."
                        for { }
                        /** @src 19:4402:4416  "i < sys.length" */ lt(var_i, /** @src 19:4406:4416  "sys.length" */ value2)
                        /// @src 19:4387:4400  "uint256 i = 0"
                        {
                            /// @src 19:4418:4421  "++i"
                            var_i := /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ add(/** @src 19:4418:4421  "++i" */ var_i, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 1)
                        }
                        /// @src 19:4418:4421  "++i"
                        {
                            /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                            let _108 := and(/** @src 19:4460:4466  "sys[i]" */ read_from_calldatat_address(calldata_array_index_access_address_dyn_calldata(value1, value2, var_i)), /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ sub(shl(160, 1), 1))
                            /// @src 19:4441:4486  "IStandardizedYield(sys[i]).claimRewards(user)"
                            let _109 := /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(64)
                            /// @src 19:4441:4486  "IStandardizedYield(sys[i]).claimRewards(user)"
                            mstore(_109, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ shl(226, 0x3bd73ee3))
                            mstore(/** @src 19:4441:4486  "IStandardizedYield(sys[i]).claimRewards(user)" */ add(_109, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 4), and(value_12, sub(shl(160, 1), 1)))
                            /// @src 19:4441:4486  "IStandardizedYield(sys[i]).claimRewards(user)"
                            let _110 := call(gas(), _108, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0, /** @src 19:4441:4486  "IStandardizedYield(sys[i]).claimRewards(user)" */ _109, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 36, /** @src 19:4441:4486  "IStandardizedYield(sys[i]).claimRewards(user)" */ _109, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0)
                            /// @src 19:4441:4486  "IStandardizedYield(sys[i]).claimRewards(user)"
                            if iszero(_110)
                            {
                                /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                                let pos_19 := mload(64)
                                returndatacopy(pos_19, 0, returndatasize())
                                revert(pos_19, returndatasize())
                            }
                            /// @src 19:4441:4486  "IStandardizedYield(sys[i]).claimRewards(user)"
                            if _110
                            {
                                let _111 := returndatasize()
                                returndatacopy(_109, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0, /** @src 19:4441:4486  "IStandardizedYield(sys[i]).claimRewards(user)" */ _111)
                                finalize_allocation(_109, _111)
                                pop(abi_decode_array_uint256_dyn_fromMemory(_109, add(_109, _111)))
                            }
                        }
                        /// @src 19:4520:4533  "uint256 i = 0"
                        let var_i_1 := /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0
                        /// @src 19:4515:4655  "for (uint256 i = 0; i < yts.length; ++i) {..."
                        for { }
                        /** @src 19:4535:4549  "i < yts.length" */ lt(var_i_1, /** @src 19:4539:4549  "yts.length" */ value4)
                        /// @src 19:4520:4533  "uint256 i = 0"
                        {
                            /// @src 19:4551:4554  "++i"
                            var_i_1 := /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ add(/** @src 19:4551:4554  "++i" */ var_i_1, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 1)
                        }
                        /// @src 19:4551:4554  "++i"
                        {
                            /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                            let _112 := and(/** @src 19:4587:4593  "yts[i]" */ read_from_calldatat_address(calldata_array_index_access_address_dyn_calldata(value3, value4, var_i_1)), /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ sub(shl(160, 1), 1))
                            /// @src 19:4574:4640  "IPYieldToken(yts[i]).redeemDueInterestAndRewards(user, true, true)"
                            let _113 := /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(64)
                            /// @src 19:4574:4640  "IPYieldToken(yts[i]).redeemDueInterestAndRewards(user, true, true)"
                            mstore(_113, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ shl(224, 0x7d24da4d))
                            mstore(/** @src 19:4574:4640  "IPYieldToken(yts[i]).redeemDueInterestAndRewards(user, true, true)" */ add(_113, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 4), and(value_12, sub(shl(160, 1), 1)))
                            let _114 := 1
                            mstore(add(/** @src 19:4574:4640  "IPYieldToken(yts[i]).redeemDueInterestAndRewards(user, true, true)" */ _113, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 36), _114)
                            mstore(add(/** @src 19:4574:4640  "IPYieldToken(yts[i]).redeemDueInterestAndRewards(user, true, true)" */ _113, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 68), _114)
                            /// @src 19:4574:4640  "IPYieldToken(yts[i]).redeemDueInterestAndRewards(user, true, true)"
                            let _115 := call(gas(), _112, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0, /** @src 19:4574:4640  "IPYieldToken(yts[i]).redeemDueInterestAndRewards(user, true, true)" */ _113, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 100, /** @src 19:4574:4640  "IPYieldToken(yts[i]).redeemDueInterestAndRewards(user, true, true)" */ _113, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0)
                            /// @src 19:4574:4640  "IPYieldToken(yts[i]).redeemDueInterestAndRewards(user, true, true)"
                            if iszero(_115)
                            {
                                /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                                let pos_20 := mload(64)
                                returndatacopy(pos_20, 0, returndatasize())
                                revert(pos_20, returndatasize())
                            }
                            /// @src 19:4574:4640  "IPYieldToken(yts[i]).redeemDueInterestAndRewards(user, true, true)"
                            if _115
                            {
                                let _116 := returndatasize()
                                returndatacopy(_113, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0, /** @src 19:4574:4640  "IPYieldToken(yts[i]).redeemDueInterestAndRewards(user, true, true)" */ _116)
                                finalize_allocation(_113, _116)
                                let _117 := add(_113, _116)
                                /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                                if slt(sub(_117, _113), 64) { revert(0, 0) }
                                let offset_3 := mload(add(_113, 32))
                                if gt(offset_3, 0xffffffffffffffff) { revert(0, 0) }
                                pop(abi_decode_array_uint256_dyn_memory_ptr_fromMemory(add(_113, offset_3), _117))
                            }
                        }
                        /// @src 19:4674:4687  "uint256 i = 0"
                        let var_i_2 := /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0
                        /// @src 19:4669:4787  "for (uint256 i = 0; i < markets.length; ++i) {..."
                        for { }
                        /** @src 19:4689:4707  "i < markets.length" */ lt(var_i_2, /** @src 19:4693:4707  "markets.length" */ value6)
                        /// @src 19:4674:4687  "uint256 i = 0"
                        {
                            /// @src 19:4709:4712  "++i"
                            var_i_2 := /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ add(/** @src 19:4709:4712  "++i" */ var_i_2, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 1)
                        }
                        /// @src 19:4709:4712  "++i"
                        {
                            /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                            let _118 := and(/** @src 19:4741:4751  "markets[i]" */ read_from_calldatat_address(calldata_array_index_access_address_dyn_calldata(value5, value6, var_i_2)), /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ sub(shl(160, 1), 1))
                            /// @src 19:4732:4772  "IPMarket(markets[i]).redeemRewards(user)"
                            let _119 := /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(64)
                            /// @src 19:4732:4772  "IPMarket(markets[i]).redeemRewards(user)"
                            mstore(_119, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ shl(224, 0x9262187b))
                            mstore(/** @src 19:4732:4772  "IPMarket(markets[i]).redeemRewards(user)" */ add(_119, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 4), and(value_12, sub(shl(160, 1), 1)))
                            /// @src 19:4732:4772  "IPMarket(markets[i]).redeemRewards(user)"
                            let _120 := call(gas(), _118, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0, /** @src 19:4732:4772  "IPMarket(markets[i]).redeemRewards(user)" */ _119, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 36, /** @src 19:4732:4772  "IPMarket(markets[i]).redeemRewards(user)" */ _119, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0)
                            /// @src 19:4732:4772  "IPMarket(markets[i]).redeemRewards(user)"
                            if iszero(_120)
                            {
                                /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                                let pos_21 := mload(64)
                                returndatacopy(pos_21, 0, returndatasize())
                                revert(pos_21, returndatasize())
                            }
                            /// @src 19:4732:4772  "IPMarket(markets[i]).redeemRewards(user)"
                            if _120
                            {
                                let _121 := returndatasize()
                                returndatacopy(_119, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0, /** @src 19:4732:4772  "IPMarket(markets[i]).redeemRewards(user)" */ _121)
                                finalize_allocation(_119, _121)
                                pop(abi_decode_array_uint256_dyn_fromMemory(_119, add(_119, _121)))
                            }
                        }
                        /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                        return(0, 0)
                    }
                }
                revert(0, 0)
            }
            function abi_decode_addresst_addresst_uint256t_uint256(dataEnd) -> value0, value1, value2, value3
            {
                if slt(add(dataEnd, not(3)), 128) { revert(0, 0) }
                let value := calldataload(4)
                let _1 := sub(shl(160, 1), 1)
                if iszero(eq(value, and(value, _1)))
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                value0 := value
                let value_1 := calldataload(36)
                if iszero(eq(value_1, and(value_1, _1)))
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                value1 := value_1
                value2 := calldataload(68)
                value3 := calldataload(100)
            }
            function abi_decode_addresst_addresst_uint256t_struct_TokenInput_calldata(dataEnd) -> value0, value1, value2, value3
            {
                let _1 := not(3)
                if slt(add(dataEnd, _1), 128) { revert(0, 0) }
                let value := calldataload(4)
                let _2 := sub(shl(160, 1), 1)
                if iszero(eq(value, and(value, _2)))
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                value0 := value
                let value_1 := calldataload(36)
                if iszero(eq(value_1, and(value_1, _2)))
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                value1 := value_1
                value2 := calldataload(68)
                let offset := calldataload(100)
                if gt(offset, 0xffffffffffffffff)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                if slt(add(sub(dataEnd, offset), _1), 192)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                value3 := add(4, offset)
            }
            function abi_decode_array_address_dyn_calldata(offset, end) -> arrayPos, length
            {
                if iszero(slt(add(offset, 0x1f), end)) { revert(0, 0) }
                length := calldataload(offset)
                if gt(length, 0xffffffffffffffff) { revert(0, 0) }
                arrayPos := add(offset, 0x20)
                if gt(add(add(offset, shl(5, length)), 0x20), end) { revert(0, 0) }
            }
            function read_from_calldatat_address(ptr) -> returnValue
            {
                let value := calldataload(ptr)
                if iszero(eq(value, and(value, sub(shl(160, 1), 1)))) { revert(0, 0) }
                returnValue := value
            }
            function abi_encode_address_uint256_uint256(headStart, value0, value1, value2) -> tail
            {
                tail := add(headStart, 96)
                mstore(headStart, and(value0, sub(shl(160, 1), 1)))
                mstore(add(headStart, 32), value1)
                mstore(add(headStart, 64), value2)
            }
            function finalize_allocation_8341(memPtr)
            {
                if gt(memPtr, 0xffffffffffffffff)
                {
                    mstore(0, shl(224, 0x4e487b71))
                    mstore(4, 0x41)
                    revert(0, 0x24)
                }
                mstore(64, memPtr)
            }
            function finalize_allocation(memPtr, size)
            {
                let newFreePtr := add(memPtr, and(add(size, 31), not(31)))
                if or(gt(newFreePtr, 0xffffffffffffffff), lt(newFreePtr, memPtr))
                {
                    mstore(0, shl(224, 0x4e487b71))
                    mstore(4, 0x41)
                    revert(0, 0x24)
                }
                mstore(64, newFreePtr)
            }
            function abi_decode_address_fromMemory(headStart, dataEnd) -> value0
            {
                if slt(sub(dataEnd, headStart), 32) { revert(0, 0) }
                let value := mload(headStart)
                if iszero(eq(value, and(value, sub(shl(160, 1), 1))))
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                value0 := value
            }
            function calldata_array_index_access_address_dyn_calldata(base_ref, length, index) -> addr
            {
                if iszero(lt(index, length))
                {
                    mstore(0, shl(224, 0x4e487b71))
                    mstore(4, 0x32)
                    revert(0, 0x24)
                }
                addr := add(base_ref, shl(5, index))
            }
            function abi_decode_array_uint256_dyn_memory_ptr_fromMemory(offset, end) -> array
            {
                if iszero(slt(add(offset, 0x1f), end)) { revert(0, 0) }
                let _1 := mload(offset)
                let _2 := 0x20
                if gt(_1, 0xffffffffffffffff)
                {
                    mstore(/** @src -1:-1:-1 */ 0, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ shl(224, 0x4e487b71))
                    mstore(4, 0x41)
                    revert(/** @src -1:-1:-1 */ 0, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0x24)
                }
                let _3 := shl(5, _1)
                let memPtr := mload(64)
                finalize_allocation(memPtr, add(_3, _2))
                let dst := memPtr
                mstore(memPtr, _1)
                dst := add(memPtr, _2)
                let srcEnd := add(add(offset, _3), _2)
                if gt(srcEnd, end)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                let src := add(offset, _2)
                for { } lt(src, srcEnd) { src := add(src, _2) }
                {
                    mstore(dst, mload(src))
                    dst := add(dst, _2)
                }
                array := memPtr
            }
            function abi_decode_array_uint256_dyn_fromMemory(headStart, dataEnd) -> value0
            {
                if slt(sub(dataEnd, headStart), 32) { revert(0, 0) }
                let offset := mload(headStart)
                if gt(offset, 0xffffffffffffffff) { revert(0, 0) }
                value0 := abi_decode_array_uint256_dyn_memory_ptr_fromMemory(add(headStart, offset), dataEnd)
            }
            function access_calldata_tail_struct_SwapData_calldata(base_ref, ptr_to_tail) -> addr
            {
                let rel_offset_of_tail := calldataload(ptr_to_tail)
                if iszero(slt(rel_offset_of_tail, add(sub(calldatasize(), base_ref), not(126)))) { revert(0, 0) }
                addr := add(base_ref, rel_offset_of_tail)
            }
            /// @src 6:352:362  "address(0)"
            function abi_encode_address_uint256_struct_SwapData_calldata(headStart, value0, value1, value2) -> tail
            {
                /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                let _1 := sub(shl(160, 1), 1)
                mstore(headStart, and(value0, _1))
                mstore(/** @src 6:352:362  "address(0)" */ add(headStart, 32), /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ value1)
                /// @src 6:352:362  "address(0)"
                mstore(add(headStart, 64), 96)
                let value := calldataload(value2)
                /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                if iszero(lt(value, 4))
                {
                    revert(/** @src 6:352:362  "address(0)" */ 0, 0)
                }
                mstore(add(headStart, 96), value)
                /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                let value_1 := calldataload(/** @src 6:352:362  "address(0)" */ add(value2, 32))
                /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                let _2 := and(value_1, _1)
                if iszero(eq(value_1, _2))
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                mstore(/** @src 6:352:362  "address(0)" */ add(headStart, 0x80), /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _2)
                /// @src 6:352:362  "address(0)"
                let rel_offset_of_tail := calldataload(add(value2, 64))
                if iszero(slt(rel_offset_of_tail, add(sub(calldatasize(), value2), not(30))))
                {
                    /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 6:352:362  "address(0)"
                let value_2 := add(rel_offset_of_tail, value2)
                let length := calldataload(value_2)
                let value_3 := add(value_2, 32)
                if gt(length, 0xffffffffffffffff)
                {
                    /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 6:352:362  "address(0)"
                if sgt(value_3, sub(calldatasize(), length))
                {
                    /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 6:352:362  "address(0)"
                mstore(add(headStart, 160), 0x80)
                mstore(add(headStart, 224), length)
                let _3 := 256
                calldatacopy(add(headStart, _3), value_3, length)
                mstore(add(add(headStart, length), _3), /** @src -1:-1:-1 */ 0)
                /// @src 6:352:362  "address(0)"
                let value_4 := calldataload(add(value2, 96))
                /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                let _4 := iszero(iszero(/** @src 6:352:362  "address(0)" */ value_4))
                if iszero(eq(value_4, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _4))
                /// @src 6:352:362  "address(0)"
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                mstore(/** @src 6:352:362  "address(0)" */ add(headStart, 192), /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _4)
                /// @src 6:352:362  "address(0)"
                tail := add(add(headStart, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ and(add(/** @src 6:352:362  "address(0)" */ length, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 31), not(31))), /** @src 6:352:362  "address(0)" */ _3)
            }
            /// @ast-id 2681 @src 6:484:762  "function _transferIn(..."
            function fun_transferIn(var_token, var_from, var_amount)
            {
                /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                let _1 := and(/** @src 6:603:618  "token == NATIVE" */ var_token, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ sub(shl(160, 1), 1))
                /// @src 6:599:755  "if (token == NATIVE) require(msg.value == amount, \"eth mismatch\");..."
                switch /** @src 6:603:618  "token == NATIVE" */ iszero(/** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _1)
                case /** @src 6:599:755  "if (token == NATIVE) require(msg.value == amount, \"eth mismatch\");..." */ 0 {
                    /// @src 6:679:755  "if (amount != 0) IERC20(token).safeTransferFrom(from, address(this), amount)"
                    if /** @src 6:683:694  "amount != 0" */ iszero(iszero(var_amount))
                    /// @src 6:679:755  "if (amount != 0) IERC20(token).safeTransferFrom(from, address(this), amount)"
                    {
                        /// @src 6:748:754  "amount"
                        fun_safeTransferFrom(_1, var_from, /** @src 6:741:745  "this" */ address(), /** @src 6:748:754  "amount" */ var_amount)
                    }
                }
                default /// @src 6:599:755  "if (token == NATIVE) require(msg.value == amount, \"eth mismatch\");..."
                {
                    /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                    if iszero(/** @src 6:628:647  "msg.value == amount" */ eq(/** @src 6:628:637  "msg.value" */ callvalue(), /** @src 6:628:647  "msg.value == amount" */ var_amount))
                    /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                    {
                        let memPtr := mload(64)
                        mstore(memPtr, shl(229, 4594637))
                        mstore(add(memPtr, 4), 32)
                        /// @src 6:352:362  "address(0)"
                        mstore(/** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ add(memPtr, 36), 12)
                        mstore(/** @src 6:352:362  "address(0)" */ add(/** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ memPtr, /** @src 6:352:362  "address(0)" */ 68), /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ "eth mismatch")
                        revert(memPtr, 100)
                    }
                }
            }
            /// @ast-id 2825 @src 6:1758:1933  "function _selfBalance(address token) internal view returns (uint256) {..."
            function fun_selfBalance(var_token) -> var
            {
                /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                let _1 := and(/** @src 6:1845:1860  "token == NATIVE" */ var_token, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ sub(shl(160, 1), 1))
                /// @src 6:1844:1926  "(token == NATIVE) ? address(this).balance : IERC20(token).balanceOf(address(this))"
                let expr := /** @src 6:360:361  "0" */ 0x00
                /// @src 6:1844:1926  "(token == NATIVE) ? address(this).balance : IERC20(token).balanceOf(address(this))"
                switch /** @src 6:1845:1860  "token == NATIVE" */ iszero(/** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _1)
                case /** @src 6:1844:1926  "(token == NATIVE) ? address(this).balance : IERC20(token).balanceOf(address(this))" */ 0 {
                    /// @src 6:1888:1926  "IERC20(token).balanceOf(address(this))"
                    let _2 := /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(64)
                    /// @src 6:1888:1926  "IERC20(token).balanceOf(address(this))"
                    mstore(_2, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ shl(224, 0x70a08231))
                    mstore(/** @src 6:1888:1926  "IERC20(token).balanceOf(address(this))" */ add(_2, 4), /** @src 6:1920:1924  "this" */ address())
                    /// @src 6:1888:1926  "IERC20(token).balanceOf(address(this))"
                    let _3 := staticcall(gas(), _1, _2, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 36, /** @src 6:1888:1926  "IERC20(token).balanceOf(address(this))" */ _2, 32)
                    if iszero(_3)
                    {
                        /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                        let pos := mload(64)
                        returndatacopy(pos, /** @src 6:360:361  "0" */ expr, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ returndatasize())
                        revert(pos, returndatasize())
                    }
                    /// @src 6:1888:1926  "IERC20(token).balanceOf(address(this))"
                    let expr_1 := /** @src 6:360:361  "0" */ expr
                    /// @src 6:1888:1926  "IERC20(token).balanceOf(address(this))"
                    if _3
                    {
                        let _4 := 32
                        if gt(_4, returndatasize()) { _4 := returndatasize() }
                        finalize_allocation(_2, _4)
                        /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                        if slt(sub(/** @src 6:1888:1926  "IERC20(token).balanceOf(address(this))" */ add(_2, _4), /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _2), /** @src 6:1888:1926  "IERC20(token).balanceOf(address(this))" */ 32)
                        /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                        {
                            revert(/** @src 6:360:361  "0" */ expr, expr)
                        }
                        /// @src 6:1888:1926  "IERC20(token).balanceOf(address(this))"
                        expr_1 := /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(_2)
                    }
                    /// @src 6:1844:1926  "(token == NATIVE) ? address(this).balance : IERC20(token).balanceOf(address(this))"
                    expr := expr_1
                }
                default {
                    expr := /** @src 6:1864:1885  "address(this).balance" */ selfbalance()
                }
                /// @src 6:1837:1926  "return (token == NATIVE) ? address(this).balance : IERC20(token).balanceOf(address(this))"
                var := expr
            }
            /// @ast-id 2960 @src 6:2910:3166  "function _wrap_unwrap_ETH(..."
            function fun_wrap_unwrap_ETH(var_tokenIn, var_tokenOut, var_netTokenIn)
            {
                /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                let _1 := sub(shl(160, 1), 1)
                let _2 := and(/** @src 6:3044:3061  "tokenIn == NATIVE" */ var_tokenIn, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _1)
                /// @src 6:3040:3159  "if (tokenIn == NATIVE) IWETH(tokenOut).deposit{ value: netTokenIn }();..."
                switch /** @src 6:3044:3061  "tokenIn == NATIVE" */ iszero(/** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _2)
                case /** @src 6:3040:3159  "if (tokenIn == NATIVE) IWETH(tokenOut).deposit{ value: netTokenIn }();..." */ 0 {
                    /// @src 6:3124:3159  "IWETH(tokenIn).withdraw(netTokenIn)"
                    if iszero(extcodesize(_2))
                    {
                        /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                        revert(/** @src 6:360:361  "0" */ 0x00, 0x00)
                    }
                    /// @src 6:3124:3159  "IWETH(tokenIn).withdraw(netTokenIn)"
                    let _3 := /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(64)
                    /// @src 6:3124:3159  "IWETH(tokenIn).withdraw(netTokenIn)"
                    mstore(_3, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ shl(224, 0x2e1a7d4d))
                    mstore(/** @src 6:3124:3159  "IWETH(tokenIn).withdraw(netTokenIn)" */ add(_3, 4), /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ var_netTokenIn)
                    /// @src 6:3124:3159  "IWETH(tokenIn).withdraw(netTokenIn)"
                    let _4 := call(gas(), _2, /** @src 6:360:361  "0" */ 0x00, /** @src 6:3124:3159  "IWETH(tokenIn).withdraw(netTokenIn)" */ _3, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 36, /** @src 6:3124:3159  "IWETH(tokenIn).withdraw(netTokenIn)" */ _3, /** @src 6:360:361  "0" */ 0x00)
                    /// @src 6:3124:3159  "IWETH(tokenIn).withdraw(netTokenIn)"
                    if iszero(_4)
                    {
                        /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                        let pos := mload(64)
                        returndatacopy(pos, /** @src 6:360:361  "0" */ 0x00, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ returndatasize())
                        revert(pos, returndatasize())
                    }
                    /// @src 6:3124:3159  "IWETH(tokenIn).withdraw(netTokenIn)"
                    if _4 { finalize_allocation_8341(_3) }
                }
                default /// @src 6:3040:3159  "if (tokenIn == NATIVE) IWETH(tokenOut).deposit{ value: netTokenIn }();..."
                {
                    /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                    let _5 := and(/** @src 6:3063:3078  "IWETH(tokenOut)" */ var_tokenOut, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _1)
                    /// @src 6:3063:3109  "IWETH(tokenOut).deposit{ value: netTokenIn }()"
                    if iszero(extcodesize(_5))
                    {
                        /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                        revert(/** @src 6:360:361  "0" */ 0x00, 0x00)
                    }
                    /// @src 6:3063:3109  "IWETH(tokenOut).deposit{ value: netTokenIn }()"
                    let _6 := /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(64)
                    /// @src 6:3063:3109  "IWETH(tokenOut).deposit{ value: netTokenIn }()"
                    mstore(_6, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ shl(228, 0x0d0e30db))
                    /// @src 6:3063:3109  "IWETH(tokenOut).deposit{ value: netTokenIn }()"
                    let _7 := call(gas(), _5, var_netTokenIn, _6, 4, _6, /** @src 6:360:361  "0" */ 0x00)
                    /// @src 6:3063:3109  "IWETH(tokenOut).deposit{ value: netTokenIn }()"
                    if iszero(_7)
                    {
                        /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                        let pos_1 := mload(64)
                        returndatacopy(pos_1, /** @src 6:360:361  "0" */ 0x00, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ returndatasize())
                        revert(pos_1, returndatasize())
                    }
                    /// @src 6:3063:3109  "IWETH(tokenOut).deposit{ value: netTokenIn }()"
                    if _7 { finalize_allocation_8341(_6) }
                }
            }
            /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
            function extract_returndata() -> data
            {
                switch returndatasize()
                case 0 { data := 96 }
                default {
                    let _1 := returndatasize()
                    if gt(_1, 0xffffffffffffffff)
                    {
                        mstore(/** @src -1:-1:-1 */ 0, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ shl(224, 0x4e487b71))
                        mstore(4, 0x41)
                        revert(/** @src -1:-1:-1 */ 0, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0x24)
                    }
                    let memPtr := mload(64)
                    finalize_allocation(memPtr, add(and(add(_1, 31), not(31)), 0x20))
                    mstore(memPtr, _1)
                    data := memPtr
                    returndatacopy(add(memPtr, 0x20), /** @src -1:-1:-1 */ 0, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ returndatasize())
                }
            }
            /// @ast-id 2749 @src 6:974:1338  "function _transferOut(..."
            function fun_transferOut(var_token, var_to, var_amount)
            {
                /// @src 6:1088:1112  "if (amount == 0) return;"
                if /** @src 6:1092:1103  "amount == 0" */ iszero(var_amount)
                /// @src 6:1088:1112  "if (amount == 0) return;"
                {
                    /// @src 6:1105:1112  "return;"
                    leave
                }
                /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                let _1 := sub(shl(160, 1), 1)
                let _2 := and(/** @src 6:1125:1140  "token == NATIVE" */ var_token, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _1)
                /// @src 6:1121:1332  "if (token == NATIVE) {..."
                switch /** @src 6:1125:1140  "token == NATIVE" */ iszero(/** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _2)
                case /** @src 6:1121:1332  "if (token == NATIVE) {..." */ 0 {
                    /// @src 26:902:960  "abi.encodeWithSelector(token.transfer.selector, to, value)"
                    let expr_mpos := /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(64)
                    /// @src 26:902:960  "abi.encodeWithSelector(token.transfer.selector, to, value)"
                    mstore(add(expr_mpos, 0x20), /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ shl(224, 0xa9059cbb))
                    mstore(/** @src 26:902:960  "abi.encodeWithSelector(token.transfer.selector, to, value)" */ add(expr_mpos, 36), /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ and(var_to, _1))
                    mstore(add(/** @src 26:902:960  "abi.encodeWithSelector(token.transfer.selector, to, value)" */ expr_mpos, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 68), var_amount)
                    /// @src 26:902:960  "abi.encodeWithSelector(token.transfer.selector, to, value)"
                    mstore(expr_mpos, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 68)
                    let newFreePtr := add(expr_mpos, 128)
                    if or(gt(newFreePtr, 0xffffffffffffffff), lt(newFreePtr, expr_mpos))
                    {
                        mstore(0, shl(224, 0x4e487b71))
                        mstore(4, 0x41)
                        revert(0, /** @src 26:902:960  "abi.encodeWithSelector(token.transfer.selector, to, value)" */ 36)
                    }
                    /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                    mstore(64, newFreePtr)
                    /// @src 26:902:960  "abi.encodeWithSelector(token.transfer.selector, to, value)"
                    fun_callOptionalReturn(_2, expr_mpos)
                }
                default /// @src 6:1121:1332  "if (token == NATIVE) {..."
                {
                    /// @src 6:1175:1203  "to.call{ value: amount }(\"\")"
                    let expr_component := call(gas(), var_to, var_amount, /** @src 6:1102:1103  "0" */ 0x00, 0x00, 0x00, 0x00)
                    /// @src 6:1175:1203  "to.call{ value: amount }(\"\")"
                    pop(extract_returndata())
                    /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                    if iszero(expr_component)
                    {
                        let memPtr := mload(64)
                        mstore(memPtr, shl(229, 4594637))
                        mstore(add(memPtr, 4), 32)
                        /// @src 6:352:362  "address(0)"
                        mstore(/** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ add(memPtr, 36), 15)
                        mstore(/** @src 6:352:362  "address(0)" */ add(/** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ memPtr, /** @src 6:352:362  "address(0)" */ 68), /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ "eth send failed")
                        revert(memPtr, 100)
                    }
                }
            }
            /// @ast-id 6512 @src 20:4192:4956  "function __redeemSy(..."
            function fun_redeemSy(var_receiver, var_SY, var_netSyIn, var_out_offset) -> var_netTokenRedeemed
            {
                /// @src 20:4514:4522  "out.bulk"
                let _1 := add(var_out_offset, 96)
                /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                let _2 := sub(shl(160, 1), 1)
                /// @src 20:4510:4950  "if (out.bulk != address(0)) {..."
                switch /** @src 20:4514:4536  "out.bulk != address(0)" */ iszero(iszero(/** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ and(/** @src 20:4514:4522  "out.bulk" */ read_from_calldatat_address(_1), /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _2)))
                case /** @src 20:4510:4950  "if (out.bulk != address(0)) {..." */ 0 {
                    /// @src 20:4867:4884  "out.tokenRedeemSy"
                    let expr := read_from_calldatat_address(add(var_out_offset, 64))
                    /// @src 20:4769:4939  "IStandardizedYield(SY).redeem(..."
                    let _3 := /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(/** @src 20:4867:4884  "out.tokenRedeemSy" */ 64)
                    /// @src 20:4769:4939  "IStandardizedYield(SY).redeem(..."
                    mstore(_3, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ shl(224, 0x769f8e5d))
                    mstore(/** @src 20:4769:4939  "IStandardizedYield(SY).redeem(..." */ add(_3, 4), /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ and(var_receiver, _2))
                    mstore(add(/** @src 20:4769:4939  "IStandardizedYield(SY).redeem(..." */ _3, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 36), var_netSyIn)
                    mstore(add(/** @src 20:4769:4939  "IStandardizedYield(SY).redeem(..." */ _3, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 68), and(expr, _2))
                    let _4 := 0
                    mstore(add(/** @src 20:4769:4939  "IStandardizedYield(SY).redeem(..." */ _3, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 100), _4)
                    mstore(add(/** @src 20:4769:4939  "IStandardizedYield(SY).redeem(..." */ _3, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 132), /** @src 20:4921:4925  "true" */ 0x01)
                    /// @src 20:4769:4939  "IStandardizedYield(SY).redeem(..."
                    let _5 := call(gas(), /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ and(/** @src 20:4769:4791  "IStandardizedYield(SY)" */ var_SY, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _2), _4, /** @src 20:4769:4939  "IStandardizedYield(SY).redeem(..." */ _3, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 164, /** @src 20:4769:4939  "IStandardizedYield(SY).redeem(..." */ _3, 32)
                    if iszero(_5)
                    {
                        /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                        let pos := mload(/** @src 20:4867:4884  "out.tokenRedeemSy" */ 64)
                        /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                        returndatacopy(pos, _4, returndatasize())
                        revert(pos, returndatasize())
                    }
                    /// @src 20:4769:4939  "IStandardizedYield(SY).redeem(..."
                    let expr_1 := /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _4
                    /// @src 20:4769:4939  "IStandardizedYield(SY).redeem(..."
                    if _5
                    {
                        let _6 := 32
                        if gt(_6, returndatasize()) { _6 := returndatasize() }
                        finalize_allocation(_3, _6)
                        /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                        if slt(sub(/** @src 20:4769:4939  "IStandardizedYield(SY).redeem(..." */ add(_3, _6), /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _3), /** @src 20:4769:4939  "IStandardizedYield(SY).redeem(..." */ 32)
                        /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                        { revert(_4, _4) }
                        /// @src 20:4769:4939  "IStandardizedYield(SY).redeem(..."
                        expr_1 := /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(_3)
                    }
                    /// @src 20:4750:4939  "netTokenRedeemed = IStandardizedYield(SY).redeem(..."
                    var_netTokenRedeemed := expr_1
                }
                default /// @src 20:4510:4950  "if (out.bulk != address(0)) {..."
                {
                    /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                    let _7 := and(/** @src 20:4584:4592  "out.bulk" */ read_from_calldatat_address(_1), /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _2)
                    /// @src 20:4571:4719  "IPBulkSeller(out.bulk).swapExactSyForToken(..."
                    let _8 := /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(64)
                    /// @src 20:4571:4719  "IPBulkSeller(out.bulk).swapExactSyForToken(..."
                    mstore(_8, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ shl(225, 0x41fadbb3))
                    mstore(/** @src 20:4571:4719  "IPBulkSeller(out.bulk).swapExactSyForToken(..." */ add(_8, 4), /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ and(var_receiver, _2))
                    mstore(add(/** @src 20:4571:4719  "IPBulkSeller(out.bulk).swapExactSyForToken(..." */ _8, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 36), var_netSyIn)
                    let _9 := 0
                    mstore(add(/** @src 20:4571:4719  "IPBulkSeller(out.bulk).swapExactSyForToken(..." */ _8, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 68), _9)
                    mstore(add(/** @src 20:4571:4719  "IPBulkSeller(out.bulk).swapExactSyForToken(..." */ _8, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 100), /** @src 20:4701:4705  "true" */ 0x01)
                    /// @src 20:4571:4719  "IPBulkSeller(out.bulk).swapExactSyForToken(..."
                    let _10 := call(gas(), _7, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _9, /** @src 20:4571:4719  "IPBulkSeller(out.bulk).swapExactSyForToken(..." */ _8, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 132, /** @src 20:4571:4719  "IPBulkSeller(out.bulk).swapExactSyForToken(..." */ _8, 32)
                    if iszero(_10)
                    {
                        /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                        let pos_1 := mload(64)
                        returndatacopy(pos_1, _9, returndatasize())
                        revert(pos_1, returndatasize())
                    }
                    /// @src 20:4571:4719  "IPBulkSeller(out.bulk).swapExactSyForToken(..."
                    let expr_2 := /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _9
                    /// @src 20:4571:4719  "IPBulkSeller(out.bulk).swapExactSyForToken(..."
                    if _10
                    {
                        let _11 := 32
                        if gt(_11, returndatasize()) { _11 := returndatasize() }
                        finalize_allocation(_8, _11)
                        /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                        if slt(sub(/** @src 20:4571:4719  "IPBulkSeller(out.bulk).swapExactSyForToken(..." */ add(_8, _11), /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _8), /** @src 20:4571:4719  "IPBulkSeller(out.bulk).swapExactSyForToken(..." */ 32)
                        /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                        { revert(_9, _9) }
                        /// @src 20:4571:4719  "IPBulkSeller(out.bulk).swapExactSyForToken(..."
                        expr_2 := /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(_8)
                    }
                    /// @src 20:4552:4719  "netTokenRedeemed = IPBulkSeller(out.bulk).swapExactSyForToken(..."
                    var_netTokenRedeemed := expr_2
                }
            }
            /// @ast-id 6512 @src 20:4192:4956  "function __redeemSy(..."
            function fun__redeemSy(var_receiver, var_SY, var_netSyIn, var_out_offset) -> var_netTokenRedeemed
            {
                /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                let _1 := sub(shl(160, 1), 1)
                let _2 := and(/** @src 20:4437:4447  "IERC20(SY)" */ var_SY, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _1)
                /// @src 20:4461:4479  "_syOrBulk(SY, out)"
                let _3 := fun_syOrBulk(var_SY, var_out_offset)
                /// @src 6:904:961  "if (amount != 0) token.safeTransferFrom(from, to, amount)"
                if /** @src 6:908:919  "amount != 0" */ iszero(iszero(var_netSyIn))
                /// @src 6:904:961  "if (amount != 0) token.safeTransferFrom(from, to, amount)"
                {
                    /// @src 6:954:960  "amount"
                    fun_safeTransferFrom(_2, /** @src 20:4449:4459  "msg.sender" */ caller(), /** @src 6:954:960  "amount" */ _3, var_netSyIn)
                }
                /// @src 20:4514:4522  "out.bulk"
                let _4 := add(var_out_offset, 96)
                /// @src 20:4510:4950  "if (out.bulk != address(0)) {..."
                switch /** @src 20:4514:4536  "out.bulk != address(0)" */ iszero(iszero(/** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ and(/** @src 20:4514:4522  "out.bulk" */ read_from_calldatat_address(_4), /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _1)))
                case /** @src 20:4510:4950  "if (out.bulk != address(0)) {..." */ 0 {
                    /// @src 20:4867:4884  "out.tokenRedeemSy"
                    let expr := read_from_calldatat_address(add(var_out_offset, 64))
                    /// @src 20:4769:4939  "IStandardizedYield(SY).redeem(..."
                    let _5 := /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(/** @src 20:4867:4884  "out.tokenRedeemSy" */ 64)
                    /// @src 20:4769:4939  "IStandardizedYield(SY).redeem(..."
                    mstore(_5, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ shl(224, 0x769f8e5d))
                    mstore(/** @src 20:4769:4939  "IStandardizedYield(SY).redeem(..." */ add(_5, 4), /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ and(var_receiver, _1))
                    mstore(add(/** @src 20:4769:4939  "IStandardizedYield(SY).redeem(..." */ _5, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 36), var_netSyIn)
                    mstore(add(/** @src 20:4769:4939  "IStandardizedYield(SY).redeem(..." */ _5, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 68), and(expr, _1))
                    /// @src 20:4534:4535  "0"
                    let _6 := 0x00
                    /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                    mstore(add(/** @src 20:4769:4939  "IStandardizedYield(SY).redeem(..." */ _5, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 100), /** @src 20:4534:4535  "0" */ _6)
                    /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                    mstore(add(/** @src 20:4769:4939  "IStandardizedYield(SY).redeem(..." */ _5, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 132), /** @src 19:1461:1465  "true" */ 0x01)
                    /// @src 20:4769:4939  "IStandardizedYield(SY).redeem(..."
                    let _7 := call(gas(), _2, /** @src 20:4534:4535  "0" */ _6, /** @src 20:4769:4939  "IStandardizedYield(SY).redeem(..." */ _5, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 164, /** @src 20:4769:4939  "IStandardizedYield(SY).redeem(..." */ _5, 32)
                    if iszero(_7)
                    {
                        /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                        let pos := mload(/** @src 20:4867:4884  "out.tokenRedeemSy" */ 64)
                        /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                        returndatacopy(pos, /** @src 20:4534:4535  "0" */ _6, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ returndatasize())
                        revert(pos, returndatasize())
                    }
                    /// @src 20:4769:4939  "IStandardizedYield(SY).redeem(..."
                    let expr_1 := /** @src 20:4534:4535  "0" */ _6
                    /// @src 20:4769:4939  "IStandardizedYield(SY).redeem(..."
                    if _7
                    {
                        let _8 := 32
                        if gt(_8, returndatasize()) { _8 := returndatasize() }
                        finalize_allocation(_5, _8)
                        /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                        if slt(sub(/** @src 20:4769:4939  "IStandardizedYield(SY).redeem(..." */ add(_5, _8), /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _5), /** @src 20:4769:4939  "IStandardizedYield(SY).redeem(..." */ 32)
                        /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                        {
                            revert(/** @src 20:4534:4535  "0" */ _6, _6)
                        }
                        /// @src 20:4769:4939  "IStandardizedYield(SY).redeem(..."
                        expr_1 := /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(_5)
                    }
                    /// @src 20:4750:4939  "netTokenRedeemed = IStandardizedYield(SY).redeem(..."
                    var_netTokenRedeemed := expr_1
                }
                default /// @src 20:4510:4950  "if (out.bulk != address(0)) {..."
                {
                    /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                    let _9 := and(/** @src 20:4584:4592  "out.bulk" */ read_from_calldatat_address(_4), /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _1)
                    /// @src 20:4571:4719  "IPBulkSeller(out.bulk).swapExactSyForToken(..."
                    let _10 := /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(64)
                    /// @src 20:4571:4719  "IPBulkSeller(out.bulk).swapExactSyForToken(..."
                    mstore(_10, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ shl(225, 0x41fadbb3))
                    mstore(/** @src 20:4571:4719  "IPBulkSeller(out.bulk).swapExactSyForToken(..." */ add(_10, 4), /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ and(var_receiver, _1))
                    mstore(add(/** @src 20:4571:4719  "IPBulkSeller(out.bulk).swapExactSyForToken(..." */ _10, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 36), var_netSyIn)
                    /// @src 20:4534:4535  "0"
                    let _11 := 0x00
                    /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                    mstore(add(/** @src 20:4571:4719  "IPBulkSeller(out.bulk).swapExactSyForToken(..." */ _10, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 68), /** @src 20:4534:4535  "0" */ _11)
                    /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                    mstore(add(/** @src 20:4571:4719  "IPBulkSeller(out.bulk).swapExactSyForToken(..." */ _10, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 100), /** @src 19:1461:1465  "true" */ 0x01)
                    /// @src 20:4571:4719  "IPBulkSeller(out.bulk).swapExactSyForToken(..."
                    let _12 := call(gas(), _9, /** @src 20:4534:4535  "0" */ _11, /** @src 20:4571:4719  "IPBulkSeller(out.bulk).swapExactSyForToken(..." */ _10, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 132, /** @src 20:4571:4719  "IPBulkSeller(out.bulk).swapExactSyForToken(..." */ _10, 32)
                    if iszero(_12)
                    {
                        /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                        let pos_1 := mload(64)
                        returndatacopy(pos_1, /** @src 20:4534:4535  "0" */ _11, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ returndatasize())
                        revert(pos_1, returndatasize())
                    }
                    /// @src 20:4571:4719  "IPBulkSeller(out.bulk).swapExactSyForToken(..."
                    let expr_2 := /** @src 20:4534:4535  "0" */ _11
                    /// @src 20:4571:4719  "IPBulkSeller(out.bulk).swapExactSyForToken(..."
                    if _12
                    {
                        let _13 := 32
                        if gt(_13, returndatasize()) { _13 := returndatasize() }
                        finalize_allocation(_10, _13)
                        /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                        if slt(sub(/** @src 20:4571:4719  "IPBulkSeller(out.bulk).swapExactSyForToken(..." */ add(_10, _13), /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _10), /** @src 20:4571:4719  "IPBulkSeller(out.bulk).swapExactSyForToken(..." */ 32)
                        /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                        {
                            revert(/** @src 20:4534:4535  "0" */ _11, _11)
                        }
                        /// @src 20:4571:4719  "IPBulkSeller(out.bulk).swapExactSyForToken(..."
                        expr_2 := /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(_10)
                    }
                    /// @src 20:4552:4719  "netTokenRedeemed = IPBulkSeller(out.bulk).swapExactSyForToken(..."
                    var_netTokenRedeemed := expr_2
                }
            }
            /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
            function abi_decode_bool_fromMemory(headStart, dataEnd) -> value0
            {
                if slt(sub(dataEnd, headStart), 32) { revert(0, 0) }
                let value := mload(headStart)
                /// @src 6:352:362  "address(0)"
                if iszero(eq(value, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ iszero(iszero(/** @src 6:352:362  "address(0)" */ value))))
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                value0 := value
            }
            /// @ast-id 6661 @src 20:6000:6193  "function _syOrBulk(address SY, TokenOutput calldata output)..."
            function fun_syOrBulk(var_SY, var_output_offset) -> var_addr
            {
                /// @src 20:6142:6153  "output.bulk"
                let _1 := add(var_output_offset, 96)
                /// @src 20:6142:6167  "output.bulk != address(0)"
                let expr := iszero(iszero(/** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ and(/** @src 20:6142:6153  "output.bulk" */ read_from_calldatat_address(_1), /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ sub(shl(160, 1), 1))))
                /// @src 20:6142:6186  "output.bulk != address(0) ? output.bulk : SY"
                let expr_1 := /** @src 20:6165:6166  "0" */ 0x00
                /// @src 20:6142:6186  "output.bulk != address(0) ? output.bulk : SY"
                switch expr
                case 0 { expr_1 := var_SY }
                default {
                    expr_1 := /** @src 20:6170:6181  "output.bulk" */ read_from_calldatat_address(_1)
                }
                /// @src 20:6135:6186  "return output.bulk != address(0) ? output.bulk : SY"
                var_addr := expr_1
            }
            /// @ast-id 8801 @src 26:974:1215  "function safeTransferFrom(..."
            function fun_safeTransferFrom(var_token_8778_address, var_from, var_to, var_value)
            {
                /// @src 26:1139:1207  "abi.encodeWithSelector(token.transferFrom.selector, from, to, value)"
                let expr_mpos := /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(64)
                /// @src 26:1139:1207  "abi.encodeWithSelector(token.transferFrom.selector, from, to, value)"
                mstore(add(expr_mpos, 0x20), /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ shl(224, 0x23b872dd))
                let _1 := sub(shl(160, 1), 1)
                mstore(/** @src 26:1139:1207  "abi.encodeWithSelector(token.transferFrom.selector, from, to, value)" */ add(expr_mpos, 36), /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ and(var_from, _1))
                mstore(add(/** @src 26:1139:1207  "abi.encodeWithSelector(token.transferFrom.selector, from, to, value)" */ expr_mpos, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 68), and(var_to, _1))
                mstore(add(/** @src 26:1139:1207  "abi.encodeWithSelector(token.transferFrom.selector, from, to, value)" */ expr_mpos, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 100), var_value)
                /// @src 26:1139:1207  "abi.encodeWithSelector(token.transferFrom.selector, from, to, value)"
                mstore(expr_mpos, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 100)
                let newFreePtr := add(expr_mpos, 160)
                if or(gt(newFreePtr, 0xffffffffffffffff), lt(newFreePtr, expr_mpos))
                {
                    mstore(0, shl(224, 0x4e487b71))
                    mstore(4, 0x41)
                    revert(0, /** @src 26:1139:1207  "abi.encodeWithSelector(token.transferFrom.selector, from, to, value)" */ 36)
                }
                /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                mstore(64, newFreePtr)
                /// @src 26:1139:1207  "abi.encodeWithSelector(token.transferFrom.selector, from, to, value)"
                fun_callOptionalReturn(var_token_8778_address, expr_mpos)
            }
            /// @ast-id 9023 @src 26:3747:4453  "function _callOptionalReturn(IERC20 token, bytes memory data) private {..."
            function fun_callOptionalReturn(var_token_address, var_data_mpos)
            {
                /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                let _1 := and(/** @src 26:4192:4206  "address(token)" */ var_token_address, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ sub(shl(160, 1), 1))
                let memPtr := mload(64)
                let newFreePtr := add(memPtr, 64)
                if or(gt(newFreePtr, 0xffffffffffffffff), lt(newFreePtr, memPtr))
                {
                    mstore(0, shl(224, 0x4e487b71))
                    mstore(4, 0x41)
                    revert(0, 0x24)
                }
                mstore(64, newFreePtr)
                let _2 := 32
                mstore(memPtr, _2)
                mstore(add(memPtr, _2), "SafeERC20: low-level call failed")
                if /** @src 27:1465:1488  "account.code.length > 0" */ iszero(/** @src 27:1465:1484  "account.code.length" */ extcodesize(_1))
                /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                {
                    let memPtr_1 := mload(64)
                    mstore(memPtr_1, shl(229, 4594637))
                    mstore(add(memPtr_1, 4), _2)
                    /// @src 6:352:362  "address(0)"
                    mstore(/** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ add(memPtr_1, 36), 29)
                    mstore(/** @src 6:352:362  "address(0)" */ add(/** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ memPtr_1, /** @src 6:352:362  "address(0)" */ 68), /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ "Address: call to non-contract")
                    revert(memPtr_1, 100)
                }
                /// @src 27:5341:5372  "target.call{value: value}(data)"
                let expr_component := call(gas(), _1, /** @src -1:-1:-1 */ 0, /** @src 27:5341:5372  "target.call{value: value}(data)" */ add(var_data_mpos, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _2), /** @src 27:5341:5372  "target.call{value: value}(data)" */ mload(var_data_mpos), /** @src -1:-1:-1 */ 0, 0)
                /// @src 27:5382:5440  "return verifyCallResult(success, returndata, errorMessage)"
                let var__mpos := /** @src 27:5389:5440  "verifyCallResult(success, returndata, errorMessage)" */ fun_verifyCallResult(expr_component, /** @src 27:5341:5372  "target.call{value: value}(data)" */ extract_returndata(), /** @src 27:5389:5440  "verifyCallResult(success, returndata, errorMessage)" */ memPtr)
                /// @src 26:4275:4292  "returndata.length"
                let expr := /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(/** @src 26:4275:4292  "returndata.length" */ var__mpos)
                /// @src 26:4271:4447  "if (returndata.length > 0) {..."
                if /** @src 26:4275:4296  "returndata.length > 0" */ iszero(iszero(expr))
                /// @src 26:4271:4447  "if (returndata.length > 0) {..."
                {
                    /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                    if iszero(/** @src 26:4359:4389  "abi.decode(returndata, (bool))" */ abi_decode_bool_fromMemory(add(var__mpos, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _2), /** @src 26:4359:4389  "abi.decode(returndata, (bool))" */ add(add(var__mpos, expr), /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _2)))
                    {
                        let memPtr_2 := mload(64)
                        mstore(memPtr_2, shl(229, 4594637))
                        mstore(add(memPtr_2, 4), _2)
                        /// @src 6:352:362  "address(0)"
                        mstore(/** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ add(memPtr_2, 36), 42)
                        mstore(/** @src 6:352:362  "address(0)" */ add(/** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ memPtr_2, /** @src 6:352:362  "address(0)" */ 68), /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ "SafeERC20: ERC20 operation did n")
                        mstore(add(memPtr_2, 100), "ot succeed")
                        revert(memPtr_2, 132)
                    }
                }
            }
            /// @ast-id 9318 @src 27:7561:8303  "function verifyCallResult(..."
            function fun_verifyCallResult(var_success, var_returndata_mpos, var_errorMessage_mpos) -> var_mpos
            {
                /// @src 27:7707:7719  "bytes memory"
                var_mpos := /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 96
                /// @src 27:7731:8297  "if (success) {..."
                switch var_success
                case 0 {
                    /// @src 27:7872:8287  "if (returndata.length > 0) {..."
                    switch /** @src 27:7876:7897  "returndata.length > 0" */ iszero(iszero(/** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(/** @src 27:7876:7893  "returndata.length" */ var_returndata_mpos)))
                    case /** @src 27:7872:8287  "if (returndata.length > 0) {..." */ 0 {
                        /// @src 27:8252:8272  "revert(errorMessage)"
                        let _1 := /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(64)
                        /// @src 27:8252:8272  "revert(errorMessage)"
                        mstore(_1, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ shl(229, 4594637))
                        let _2 := 32
                        mstore(/** @src 27:8252:8272  "revert(errorMessage)" */ add(_1, 4), /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _2)
                        let length := mload(var_errorMessage_mpos)
                        /// @src 6:352:362  "address(0)"
                        mstore(/** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ add(/** @src 27:8252:8272  "revert(errorMessage)" */ _1, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 36), /** @src 6:352:362  "address(0)" */ length)
                        /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                        let i := /** @src 27:7896:7897  "0" */ 0x00
                        /// @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                        for { } lt(i, length) { i := add(i, _2) }
                        {
                            mstore(add(add(/** @src 27:8252:8272  "revert(errorMessage)" */ _1, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ i), /** @src 6:352:362  "address(0)" */ 68), /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(add(add(var_errorMessage_mpos, i), _2)))
                        }
                        mstore(add(add(/** @src 27:8252:8272  "revert(errorMessage)" */ _1, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ length), /** @src 6:352:362  "address(0)" */ 68), /** @src 27:7896:7897  "0" */ 0x00)
                        /// @src 27:8252:8272  "revert(errorMessage)"
                        revert(_1, add(sub(/** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ add(/** @src 27:8252:8272  "revert(errorMessage)" */ _1, /** @src 19:236:4805  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ and(add(length, 31), not(31))), /** @src 27:8252:8272  "revert(errorMessage)" */ _1), /** @src 6:352:362  "address(0)" */ 68))
                    }
                    default /// @src 27:7872:8287  "if (returndata.length > 0) {..."
                    {
                        /// @src 27:8060:8214  "assembly {..."
                        revert(add(32, var_returndata_mpos), mload(var_returndata_mpos))
                    }
                }
                default /// @src 27:7731:8297  "if (success) {..."
                {
                    /// @src 27:7758:7775  "return returndata"
                    var_mpos := var_returndata_mpos
                    leave
                }
            }
        }
        data ".metadata" hex"a2646970667358221220ed7920b79592b03108446d274de8b0a48d0beea5b7c5fcc9c71d86ab53dc356864736f6c63430008110033"
    }
}


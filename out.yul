/// @use-src 6:"contracts/core/libraries/TokenHelper.sol", 9:"contracts/interfaces/IPActionMintRedeem.sol", 18:"contracts/router/ActionMintRedeem.sol", 19:"contracts/router/base/ActionBaseMintRedeem.sol", 22:"contracts/router/kyberswap/KyberSwapHelper.sol"
object "ActionMintRedeem_6032" {
    code {
        {
            /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
            let _1 := memoryguard(0xa0)
            if callvalue() { revert(0, 0) }
            let programSize := datasize("ActionMintRedeem_6032")
            let argSize := sub(codesize(), programSize)
            let newFreePtr := add(_1, and(add(argSize, 31), not(31)))
            if or(gt(newFreePtr, sub(shl(64, 1), 1)), lt(newFreePtr, _1))
            {
                mstore(/** @src -1:-1:-1 */ 0, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ shl(224, 0x4e487b71))
                mstore(4, 0x41)
                revert(/** @src -1:-1:-1 */ 0, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0x24)
            }
            mstore(64, newFreePtr)
            codecopy(_1, programSize, argSize)
            if slt(sub(add(_1, argSize), _1), 32)
            {
                revert(/** @src -1:-1:-1 */ 0, 0)
            }
            /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
            let value := mload(_1)
            if iszero(eq(value, and(value, sub(shl(160, 1), 1))))
            {
                revert(/** @src -1:-1:-1 */ 0, 0)
            }
            /// @src 22:1931:1965  "kyberScalingLib = _kyberScalingLib"
            mstore(128, value)
            /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
            let _2 := mload(64)
            let _3 := datasize("ActionMintRedeem_6032_deployed")
            codecopy(_2, dataoffset("ActionMintRedeem_6032_deployed"), _3)
            setimmutable(_2, "8471", mload(/** @src 22:1931:1965  "kyberScalingLib = _kyberScalingLib" */ 128))
            /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
            return(_2, _3)
        }
    }
    /// @use-src 6:"contracts/core/libraries/TokenHelper.sol", 18:"contracts/router/ActionMintRedeem.sol", 19:"contracts/router/base/ActionBaseMintRedeem.sol", 22:"contracts/router/kyberswap/KyberSwapHelper.sol", 26:"node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol", 27:"node_modules/@openzeppelin/contracts/utils/Address.sol"
    object "ActionMintRedeem_6032_deployed" {
        code {
            {
                /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                let _1 := memoryguard(0x80)
                mstore(64, _1)
                if iszero(lt(calldatasize(), 4))
                {
                    switch shr(224, calldataload(0))
                    case 0x1a8631b2 {
                        if callvalue() { revert(0, 0) }
                        let param, param_1, param_2, param_3 := abi_decode_addresst_addresst_uint256t_uint256(calldatasize())
                        let _2 := sub(shl(160, 1), 1)
                        let _3 := and(/** @src 18:3700:3716  "IPYieldToken(YT)" */ param_1, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _2)
                        /// @src 18:3700:3721  "IPYieldToken(YT).SY()"
                        mstore(_1, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ shl(224, 0xafd27bf5))
                        /// @src 18:3700:3721  "IPYieldToken(YT).SY()"
                        let _4 := 32
                        let _5 := staticcall(gas(), _3, _1, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 4, /** @src 18:3700:3721  "IPYieldToken(YT).SY()" */ _1, _4)
                        if iszero(_5)
                        {
                            /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                            let pos := mload(64)
                            returndatacopy(pos, 0, returndatasize())
                            revert(pos, returndatasize())
                        }
                        /// @src 18:3700:3721  "IPYieldToken(YT).SY()"
                        let expr := /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0
                        /// @src 18:3700:3721  "IPYieldToken(YT).SY()"
                        if _5
                        {
                            let _6 := _4
                            if gt(_4, returndatasize()) { _6 := returndatasize() }
                            finalize_allocation(_1, _6)
                            expr := abi_decode_address_fromMemory(_1, add(_1, _6))
                        }
                        /// @src 6:867:924  "if (amount != 0) token.safeTransferFrom(from, to, amount)"
                        if /** @src 6:871:882  "amount != 0" */ iszero(iszero(param_2))
                        /// @src 6:867:924  "if (amount != 0) token.safeTransferFrom(from, to, amount)"
                        {
                            /// @src 6:917:923  "amount"
                            fun_safeTransferFrom(/** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ and(/** @src 19:3619:3629  "IERC20(SY)" */ expr, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _2), /** @src 19:3631:3641  "msg.sender" */ caller(), /** @src 6:917:923  "amount" */ param_1, param_2)
                        }
                        /// @src 19:3687:3730  "IPYieldToken(YT).mintPY(receiver, receiver)"
                        let _7 := /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(64)
                        /// @src 19:3687:3730  "IPYieldToken(YT).mintPY(receiver, receiver)"
                        mstore(_7, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ shl(224, 0xdb74aa15))
                        let _8 := and(param, _2)
                        mstore(/** @src 19:3687:3730  "IPYieldToken(YT).mintPY(receiver, receiver)" */ add(_7, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 4), _8)
                        mstore(add(/** @src 19:3687:3730  "IPYieldToken(YT).mintPY(receiver, receiver)" */ _7, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 36), _8)
                        /// @src 19:3687:3730  "IPYieldToken(YT).mintPY(receiver, receiver)"
                        let _9 := call(gas(), _3, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0, /** @src 19:3687:3730  "IPYieldToken(YT).mintPY(receiver, receiver)" */ _7, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 68, /** @src 19:3687:3730  "IPYieldToken(YT).mintPY(receiver, receiver)" */ _7, /** @src 18:3700:3721  "IPYieldToken(YT).SY()" */ _4)
                        /// @src 19:3687:3730  "IPYieldToken(YT).mintPY(receiver, receiver)"
                        if iszero(_9)
                        {
                            /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                            let pos_1 := mload(64)
                            returndatacopy(pos_1, 0, returndatasize())
                            revert(pos_1, returndatasize())
                        }
                        /// @src 19:3687:3730  "IPYieldToken(YT).mintPY(receiver, receiver)"
                        let expr_1 := /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0
                        /// @src 19:3687:3730  "IPYieldToken(YT).mintPY(receiver, receiver)"
                        if _9
                        {
                            let _10 := /** @src 18:3700:3721  "IPYieldToken(YT).SY()" */ _4
                            /// @src 19:3687:3730  "IPYieldToken(YT).mintPY(receiver, receiver)"
                            if gt(/** @src 18:3700:3721  "IPYieldToken(YT).SY()" */ _4, /** @src 19:3687:3730  "IPYieldToken(YT).mintPY(receiver, receiver)" */ returndatasize()) { _10 := returndatasize() }
                            finalize_allocation(_7, _10)
                            /// @src 6:315:325  "address(0)"
                            if slt(sub(/** @src 19:3687:3730  "IPYieldToken(YT).mintPY(receiver, receiver)" */ add(_7, _10), /** @src 6:315:325  "address(0)" */ _7), /** @src 18:3700:3721  "IPYieldToken(YT).SY()" */ _4)
                            /// @src 6:315:325  "address(0)"
                            {
                                /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                                revert(0, 0)
                            }
                            /// @src 19:3687:3730  "IPYieldToken(YT).mintPY(receiver, receiver)"
                            expr_1 := /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(_7)
                        }
                        /// @src 19:3740:3822  "if (netPyOut < minPyOut) revert Errors.RouterInsufficientPYOut(netPyOut, minPyOut)"
                        if /** @src 19:3744:3763  "netPyOut < minPyOut" */ lt(expr_1, param_3)
                        /// @src 19:3740:3822  "if (netPyOut < minPyOut) revert Errors.RouterInsufficientPYOut(netPyOut, minPyOut)"
                        {
                            /// @src 19:3772:3822  "Errors.RouterInsufficientPYOut(netPyOut, minPyOut)"
                            let _11 := /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(64)
                            /// @src 19:3772:3822  "Errors.RouterInsufficientPYOut(netPyOut, minPyOut)"
                            mstore(_11, shl(224, 0xca935dfd))
                            /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                            mstore(/** @src 19:3772:3822  "Errors.RouterInsufficientPYOut(netPyOut, minPyOut)" */ add(_11, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 4), expr_1)
                            mstore(add(/** @src 19:3772:3822  "Errors.RouterInsufficientPYOut(netPyOut, minPyOut)" */ _11, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 36), param_3)
                            /// @src 19:3772:3822  "Errors.RouterInsufficientPYOut(netPyOut, minPyOut)"
                            revert(_11, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 68)
                        }
                        /// @src 18:3766:3823  "MintPyFromSy(msg.sender, receiver, YT, netSyIn, netPyOut)"
                        let _12 := /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(64)
                        mstore(_12, param_2)
                        mstore(add(_12, /** @src 18:3700:3721  "IPYieldToken(YT).SY()" */ _4), /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ expr_1)
                        /// @src 18:3766:3823  "MintPyFromSy(msg.sender, receiver, YT, netSyIn, netPyOut)"
                        log4(_12, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 64, /** @src 18:3766:3823  "MintPyFromSy(msg.sender, receiver, YT, netSyIn, netPyOut)" */ 0x52e05e4badd3463bad837f42fe3ba58c739d1b3081cff9bb6eb02a24034d455d, /** @src 19:3631:3641  "msg.sender" */ caller(), /** @src 18:3766:3823  "MintPyFromSy(msg.sender, receiver, YT, netSyIn, netPyOut)" */ _8, _3)
                        /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                        let memPos := mload(64)
                        mstore(memPos, expr_1)
                        return(memPos, /** @src 18:3700:3721  "IPYieldToken(YT).SY()" */ _4)
                    }
                    case /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0x339748cb {
                        if callvalue() { revert(0, 0) }
                        let param_4, param_5, param_6, param_7 := abi_decode_addresst_addresst_uint256t_uint256(calldatasize())
                        let _13 := sub(shl(160, 1), 1)
                        let _14 := and(/** @src 19:4020:4036  "IPYieldToken(YT)" */ param_5, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _13)
                        /// @src 19:4020:4041  "IPYieldToken(YT).PT()"
                        let _15 := /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(64)
                        /// @src 19:4020:4041  "IPYieldToken(YT).PT()"
                        mstore(_15, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ shl(226, 0x36501cf5))
                        /// @src 19:4020:4041  "IPYieldToken(YT).PT()"
                        let _16 := 32
                        let _17 := staticcall(gas(), _14, _15, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 4, /** @src 19:4020:4041  "IPYieldToken(YT).PT()" */ _15, _16)
                        if iszero(_17)
                        {
                            /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                            let pos_2 := mload(64)
                            returndatacopy(pos_2, 0, returndatasize())
                            revert(pos_2, returndatasize())
                        }
                        /// @src 19:4020:4041  "IPYieldToken(YT).PT()"
                        let expr_2 := /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0
                        /// @src 19:4020:4041  "IPYieldToken(YT).PT()"
                        if _17
                        {
                            let _18 := _16
                            if gt(_16, returndatasize()) { _18 := returndatasize() }
                            finalize_allocation(_15, _18)
                            expr_2 := abi_decode_address_fromMemory(_15, add(_15, _18))
                        }
                        /// @src 6:871:882  "amount != 0"
                        let _19 := iszero(iszero(param_6))
                        /// @src 6:867:924  "if (amount != 0) token.safeTransferFrom(from, to, amount)"
                        if /** @src 6:871:882  "amount != 0" */ _19
                        /// @src 6:867:924  "if (amount != 0) token.safeTransferFrom(from, to, amount)"
                        {
                            /// @src 6:917:923  "amount"
                            fun_safeTransferFrom(/** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ and(/** @src 19:4066:4076  "IERC20(PT)" */ expr_2, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _13), /** @src 19:4078:4088  "msg.sender" */ caller(), /** @src 6:917:923  "amount" */ param_5, param_6)
                        }
                        /// @src 19:4135:4163  "IPYieldToken(YT).isExpired()"
                        let _20 := /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(64)
                        /// @src 19:4135:4163  "IPYieldToken(YT).isExpired()"
                        mstore(_20, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ shl(226, 0x0bc4ed83))
                        /// @src 19:4135:4163  "IPYieldToken(YT).isExpired()"
                        let _21 := staticcall(gas(), _14, _20, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 4, /** @src 19:4135:4163  "IPYieldToken(YT).isExpired()" */ _20, /** @src 19:4020:4041  "IPYieldToken(YT).PT()" */ _16)
                        /// @src 19:4135:4163  "IPYieldToken(YT).isExpired()"
                        if iszero(_21)
                        {
                            /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                            let pos_3 := mload(64)
                            returndatacopy(pos_3, 0, returndatasize())
                            revert(pos_3, returndatasize())
                        }
                        /// @src 19:4135:4163  "IPYieldToken(YT).isExpired()"
                        let expr_3 := /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0
                        /// @src 19:4135:4163  "IPYieldToken(YT).isExpired()"
                        if _21
                        {
                            let _22 := /** @src 19:4020:4041  "IPYieldToken(YT).PT()" */ _16
                            /// @src 19:4135:4163  "IPYieldToken(YT).isExpired()"
                            if gt(/** @src 19:4020:4041  "IPYieldToken(YT).PT()" */ _16, /** @src 19:4135:4163  "IPYieldToken(YT).isExpired()" */ returndatasize()) { _22 := returndatasize() }
                            finalize_allocation(_20, _22)
                            expr_3 := abi_decode_bool_fromMemory(_20, add(_20, _22))
                        }
                        /// @src 19:4174:4242  "if (needToBurnYt) _transferFrom(IERC20(YT), msg.sender, YT, netPyIn)"
                        if /** @src 19:4134:4163  "!IPYieldToken(YT).isExpired()" */ iszero(expr_3)
                        /// @src 19:4174:4242  "if (needToBurnYt) _transferFrom(IERC20(YT), msg.sender, YT, netPyIn)"
                        {
                            /// @src 6:867:924  "if (amount != 0) token.safeTransferFrom(from, to, amount)"
                            if /** @src 6:871:882  "amount != 0" */ _19
                            /// @src 6:867:924  "if (amount != 0) token.safeTransferFrom(from, to, amount)"
                            {
                                /// @src 6:917:923  "amount"
                                fun_safeTransferFrom(_14, /** @src 19:4078:4088  "msg.sender" */ caller(), /** @src 6:917:923  "amount" */ param_5, param_6)
                            }
                        }
                        /// @src 19:4264:4299  "IPYieldToken(YT).redeemPY(receiver)"
                        let _23 := /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(64)
                        /// @src 19:4264:4299  "IPYieldToken(YT).redeemPY(receiver)"
                        mstore(_23, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ shl(224, 0xbcb7ea5d))
                        let _24 := and(param_4, _13)
                        mstore(/** @src 19:4264:4299  "IPYieldToken(YT).redeemPY(receiver)" */ add(_23, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 4), _24)
                        /// @src 19:4264:4299  "IPYieldToken(YT).redeemPY(receiver)"
                        let _25 := call(gas(), _14, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0, /** @src 19:4264:4299  "IPYieldToken(YT).redeemPY(receiver)" */ _23, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 36, /** @src 19:4264:4299  "IPYieldToken(YT).redeemPY(receiver)" */ _23, /** @src 19:4020:4041  "IPYieldToken(YT).PT()" */ _16)
                        /// @src 19:4264:4299  "IPYieldToken(YT).redeemPY(receiver)"
                        if iszero(_25)
                        {
                            /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                            let pos_4 := mload(64)
                            returndatacopy(pos_4, 0, returndatasize())
                            revert(pos_4, returndatasize())
                        }
                        /// @src 19:4264:4299  "IPYieldToken(YT).redeemPY(receiver)"
                        let expr_4 := /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0
                        /// @src 19:4264:4299  "IPYieldToken(YT).redeemPY(receiver)"
                        if _25
                        {
                            let _26 := /** @src 19:4020:4041  "IPYieldToken(YT).PT()" */ _16
                            /// @src 19:4264:4299  "IPYieldToken(YT).redeemPY(receiver)"
                            if gt(/** @src 19:4020:4041  "IPYieldToken(YT).PT()" */ _16, /** @src 19:4264:4299  "IPYieldToken(YT).redeemPY(receiver)" */ returndatasize()) { _26 := returndatasize() }
                            finalize_allocation(_23, _26)
                            /// @src 6:315:325  "address(0)"
                            if slt(sub(/** @src 19:4264:4299  "IPYieldToken(YT).redeemPY(receiver)" */ add(_23, _26), /** @src 6:315:325  "address(0)" */ _23), /** @src 19:4020:4041  "IPYieldToken(YT).PT()" */ _16)
                            /// @src 6:315:325  "address(0)"
                            {
                                /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                                revert(0, 0)
                            }
                            /// @src 19:4264:4299  "IPYieldToken(YT).redeemPY(receiver)"
                            expr_4 := /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(_23)
                        }
                        /// @src 19:4309:4391  "if (netSyOut < minSyOut) revert Errors.RouterInsufficientSyOut(netSyOut, minSyOut)"
                        if /** @src 19:4313:4332  "netSyOut < minSyOut" */ lt(expr_4, param_7)
                        /// @src 19:4309:4391  "if (netSyOut < minSyOut) revert Errors.RouterInsufficientSyOut(netSyOut, minSyOut)"
                        {
                            /// @src 19:4341:4391  "Errors.RouterInsufficientSyOut(netSyOut, minSyOut)"
                            let _27 := /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(64)
                            /// @src 19:4341:4391  "Errors.RouterInsufficientSyOut(netSyOut, minSyOut)"
                            mstore(_27, shl(225, 0x05221cf3))
                            /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                            mstore(/** @src 19:4341:4391  "Errors.RouterInsufficientSyOut(netSyOut, minSyOut)" */ add(_27, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 4), expr_4)
                            mstore(add(/** @src 19:4341:4391  "Errors.RouterInsufficientSyOut(netSyOut, minSyOut)" */ _27, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 36), param_7)
                            /// @src 19:4341:4391  "Errors.RouterInsufficientSyOut(netSyOut, minSyOut)"
                            revert(_27, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 68)
                        }
                        /// @src 18:4136:4193  "RedeemPyToSy(msg.sender, receiver, YT, netPyIn, netSyOut)"
                        let _28 := /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(64)
                        mstore(_28, param_6)
                        mstore(add(_28, /** @src 19:4020:4041  "IPYieldToken(YT).PT()" */ _16), /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ expr_4)
                        /// @src 18:4136:4193  "RedeemPyToSy(msg.sender, receiver, YT, netPyIn, netSyOut)"
                        log4(_28, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 64, /** @src 18:4136:4193  "RedeemPyToSy(msg.sender, receiver, YT, netPyIn, netSyOut)" */ 0x31af33f80f4b396e3d4e42b38ecd3e022883a9bf689fd63f47afbe1d389cb6e7, /** @src 19:4078:4088  "msg.sender" */ caller(), /** @src 18:4136:4193  "RedeemPyToSy(msg.sender, receiver, YT, netPyIn, netSyOut)" */ _24, _14)
                        /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                        let memPos_1 := mload(64)
                        mstore(memPos_1, expr_4)
                        return(memPos_1, /** @src 19:4020:4041  "IPYieldToken(YT).PT()" */ _16)
                    }
                    case /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0x46fd07b1 {
                        let param_8, param_9, param_10, param_11 := abi_decode_addresst_addresst_uint256t_struct_TokenInput_calldata(calldatasize())
                        /// @src 18:1040:1087  "_mintSyFromToken(receiver, SY, minSyOut, input)"
                        let var_netSyOut := /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0
                        /// @src 19:882:895  "input.tokenIn"
                        let expr_5 := read_from_calldatat_address(param_11)
                        /// @src 19:909:925  "input.netTokenIn"
                        let _29 := 32
                        /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                        let value := calldataload(/** @src 19:909:925  "input.netTokenIn" */ add(param_11, _29))
                        /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                        let _30 := sub(shl(160, 1), 1)
                        let _31 := and(/** @src 6:566:581  "token == NATIVE" */ expr_5, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _30)
                        /// @src 6:562:718  "if (token == NATIVE) require(msg.value == amount, \"eth mismatch\");..."
                        switch /** @src 6:566:581  "token == NATIVE" */ iszero(/** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _31)
                        case /** @src 6:562:718  "if (token == NATIVE) require(msg.value == amount, \"eth mismatch\");..." */ 0 {
                            /// @src 6:642:718  "if (amount != 0) IERC20(token).safeTransferFrom(from, address(this), amount)"
                            if /** @src 6:646:657  "amount != 0" */ iszero(iszero(value))
                            /// @src 6:642:718  "if (amount != 0) IERC20(token).safeTransferFrom(from, address(this), amount)"
                            {
                                /// @src 6:711:717  "amount"
                                fun_safeTransferFrom(_31, /** @src 19:897:907  "msg.sender" */ caller(), /** @src 6:704:708  "this" */ address(), /** @src 6:711:717  "amount" */ value)
                            }
                        }
                        default /// @src 6:562:718  "if (token == NATIVE) require(msg.value == amount, \"eth mismatch\");..."
                        {
                            /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                            if iszero(/** @src 6:591:610  "msg.value == amount" */ eq(/** @src 6:591:600  "msg.value" */ callvalue(), /** @src 6:591:610  "msg.value == amount" */ value))
                            /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                            {
                                let memPtr := mload(64)
                                mstore(memPtr, shl(229, 4594637))
                                mstore(add(memPtr, 4), /** @src 19:909:925  "input.netTokenIn" */ _29)
                                /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                                mstore(add(memPtr, 36), 12)
                                mstore(add(memPtr, 68), "eth mismatch")
                                revert(memPtr, 100)
                            }
                        }
                        /// @src 19:956:969  "input.tokenIn"
                        let expr_6 := read_from_calldatat_address(param_11)
                        /// @src 19:973:990  "input.tokenMintSy"
                        let _32 := add(param_11, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 64)
                        /// @src 19:956:990  "input.tokenIn != input.tokenMintSy"
                        let expr_7 := iszero(eq(/** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ and(/** @src 19:956:990  "input.tokenIn != input.tokenMintSy" */ expr_6, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _30), and(/** @src 19:973:990  "input.tokenMintSy" */ read_from_calldatat_address(_32), /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _30)))
                        /// @src 19:1001:1023  "uint256 netTokenMintSy"
                        let var_netTokenMintSy := /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0
                        /// @src 19:1034:1281  "if (requireSwap) {..."
                        switch expr_7
                        case 0 {
                            /// @src 19:1237:1270  "netTokenMintSy = input.netTokenIn"
                            var_netTokenMintSy := value
                        }
                        default /// @src 19:1034:1281  "if (requireSwap) {..."
                        {
                            /// @src 19:1076:1089  "input.tokenIn"
                            let expr_8 := read_from_calldatat_address(param_11)
                            /// @src 19:1109:1126  "input.kyberRouter"
                            let expr_9 := read_from_calldatat_address(add(param_11, 128))
                            /// @src 19:1128:1143  "input.kybercall"
                            let expr_offset, expr_length := access_calldata_tail_bytes_calldata(param_11, add(param_11, 160))
                            fun_kyberswap(expr_8, value, expr_9, expr_offset, expr_length)
                            /// @src 19:1158:1206  "netTokenMintSy = _selfBalance(input.tokenMintSy)"
                            var_netTokenMintSy := /** @src 19:1175:1206  "_selfBalance(input.tokenMintSy)" */ fun_selfBalance(/** @src 19:1188:1205  "input.tokenMintSy" */ read_from_calldatat_address(_32))
                        }
                        /// @src 19:1311:1338  "input.tokenMintSy == NATIVE"
                        let expr_10 := iszero(/** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ and(/** @src 19:1311:1328  "input.tokenMintSy" */ read_from_calldatat_address(_32), /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _30))
                        /// @src 19:1311:1359  "input.tokenMintSy == NATIVE ? netTokenMintSy : 0"
                        let expr_11 := /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0
                        /// @src 19:1311:1359  "input.tokenMintSy == NATIVE ? netTokenMintSy : 0"
                        switch expr_10
                        case 0 {
                            expr_11 := /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0
                        }
                        default /// @src 19:1311:1359  "input.tokenMintSy == NATIVE ? netTokenMintSy : 0"
                        { expr_11 := var_netTokenMintSy }
                        /// @src 19:1374:1384  "input.bulk"
                        let _33 := add(param_11, 96)
                        /// @src 19:1370:1823  "if (input.bulk != address(0)) {..."
                        switch /** @src 19:1374:1398  "input.bulk != address(0)" */ iszero(iszero(/** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ and(/** @src 19:1374:1384  "input.bulk" */ read_from_calldatat_address(_33), /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _30)))
                        case /** @src 19:1370:1823  "if (input.bulk != address(0)) {..." */ 0 {
                            /// @src 19:1723:1740  "input.tokenMintSy"
                            let expr_12 := read_from_calldatat_address(_32)
                            /// @src 19:1629:1812  "IStandardizedYield(SY).deposit{ value: netNative }(..."
                            let _34 := /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(64)
                            /// @src 19:1629:1812  "IStandardizedYield(SY).deposit{ value: netNative }(..."
                            mstore(_34, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ shl(224, 0x20e8c565))
                            mstore(/** @src 19:1629:1812  "IStandardizedYield(SY).deposit{ value: netNative }(..." */ add(_34, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 4), and(param_8, _30))
                            mstore(/** @src 6:315:325  "address(0)" */ add(/** @src 19:1629:1812  "IStandardizedYield(SY).deposit{ value: netNative }(..." */ _34, /** @src 6:315:325  "address(0)" */ 36), /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ and(expr_12, _30))
                            mstore(/** @src 6:315:325  "address(0)" */ add(/** @src 19:1629:1812  "IStandardizedYield(SY).deposit{ value: netNative }(..." */ _34, /** @src 6:315:325  "address(0)" */ 68), /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ var_netTokenMintSy)
                            mstore(/** @src 6:315:325  "address(0)" */ add(/** @src 19:1629:1812  "IStandardizedYield(SY).deposit{ value: netNative }(..." */ _34, /** @src 6:315:325  "address(0)" */ 100), /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ param_10)
                            /// @src 19:1629:1812  "IStandardizedYield(SY).deposit{ value: netNative }(..."
                            let _35 := call(gas(), /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ and(/** @src 19:1629:1651  "IStandardizedYield(SY)" */ param_9, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _30), /** @src 19:1629:1812  "IStandardizedYield(SY).deposit{ value: netNative }(..." */ expr_11, _34, /** @src 6:315:325  "address(0)" */ 132, /** @src 19:1629:1812  "IStandardizedYield(SY).deposit{ value: netNative }(..." */ _34, /** @src 19:909:925  "input.netTokenIn" */ _29)
                            /// @src 19:1629:1812  "IStandardizedYield(SY).deposit{ value: netNative }(..."
                            if iszero(_35)
                            {
                                /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                                let pos_5 := mload(64)
                                returndatacopy(pos_5, 0, returndatasize())
                                revert(pos_5, returndatasize())
                            }
                            /// @src 19:1629:1812  "IStandardizedYield(SY).deposit{ value: netNative }(..."
                            let expr_13 := /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0
                            /// @src 19:1629:1812  "IStandardizedYield(SY).deposit{ value: netNative }(..."
                            if _35
                            {
                                let _36 := /** @src 19:909:925  "input.netTokenIn" */ _29
                                /// @src 19:1629:1812  "IStandardizedYield(SY).deposit{ value: netNative }(..."
                                if gt(/** @src 19:909:925  "input.netTokenIn" */ _29, /** @src 19:1629:1812  "IStandardizedYield(SY).deposit{ value: netNative }(..." */ returndatasize()) { _36 := returndatasize() }
                                finalize_allocation(_34, _36)
                                /// @src 6:315:325  "address(0)"
                                if slt(sub(/** @src 19:1629:1812  "IStandardizedYield(SY).deposit{ value: netNative }(..." */ add(_34, _36), /** @src 6:315:325  "address(0)" */ _34), /** @src 19:909:925  "input.netTokenIn" */ _29)
                                /// @src 6:315:325  "address(0)"
                                {
                                    /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                                    revert(0, 0)
                                }
                                /// @src 19:1629:1812  "IStandardizedYield(SY).deposit{ value: netNative }(..."
                                expr_13 := /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(_34)
                            }
                            /// @src 19:1618:1812  "netSyOut = IStandardizedYield(SY).deposit{ value: netNative }(..."
                            var_netSyOut := expr_13
                        }
                        default /// @src 19:1370:1823  "if (input.bulk != address(0)) {..."
                        {
                            /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                            let _37 := and(/** @src 19:1438:1448  "input.bulk" */ read_from_calldatat_address(_33), /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _30)
                            /// @src 19:1425:1587  "IPBulkSeller(input.bulk).swapExactTokenForSy{ value: netNative }(..."
                            let _38 := /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(64)
                            /// @src 19:1425:1587  "IPBulkSeller(input.bulk).swapExactTokenForSy{ value: netNative }(..."
                            mstore(_38, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ shl(228, 0x0b276707))
                            /// @src 19:1425:1587  "IPBulkSeller(input.bulk).swapExactTokenForSy{ value: netNative }(..."
                            let _39 := call(gas(), _37, expr_11, _38, sub(abi_encode_address_uint256_uint256(add(_38, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 4), /** @src 19:1425:1587  "IPBulkSeller(input.bulk).swapExactTokenForSy{ value: netNative }(..." */ param_8, var_netTokenMintSy, param_10), _38), _38, /** @src 19:909:925  "input.netTokenIn" */ _29)
                            /// @src 19:1425:1587  "IPBulkSeller(input.bulk).swapExactTokenForSy{ value: netNative }(..."
                            if iszero(_39)
                            {
                                /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                                let pos_6 := mload(64)
                                returndatacopy(pos_6, 0, returndatasize())
                                revert(pos_6, returndatasize())
                            }
                            /// @src 19:1425:1587  "IPBulkSeller(input.bulk).swapExactTokenForSy{ value: netNative }(..."
                            let expr_14 := /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0
                            /// @src 19:1425:1587  "IPBulkSeller(input.bulk).swapExactTokenForSy{ value: netNative }(..."
                            if _39
                            {
                                let _40 := /** @src 19:909:925  "input.netTokenIn" */ _29
                                /// @src 19:1425:1587  "IPBulkSeller(input.bulk).swapExactTokenForSy{ value: netNative }(..."
                                if gt(/** @src 19:909:925  "input.netTokenIn" */ _29, /** @src 19:1425:1587  "IPBulkSeller(input.bulk).swapExactTokenForSy{ value: netNative }(..." */ returndatasize()) { _40 := returndatasize() }
                                finalize_allocation(_38, _40)
                                /// @src 6:315:325  "address(0)"
                                if slt(sub(/** @src 19:1425:1587  "IPBulkSeller(input.bulk).swapExactTokenForSy{ value: netNative }(..." */ add(_38, _40), /** @src 6:315:325  "address(0)" */ _38), /** @src 19:909:925  "input.netTokenIn" */ _29)
                                /// @src 6:315:325  "address(0)"
                                {
                                    /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                                    revert(0, 0)
                                }
                                /// @src 19:1425:1587  "IPBulkSeller(input.bulk).swapExactTokenForSy{ value: netNative }(..."
                                expr_14 := /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(_38)
                            }
                            /// @src 19:1414:1587  "netSyOut = IPBulkSeller(input.bulk).swapExactTokenForSy{ value: netNative }(..."
                            var_netSyOut := expr_14
                        }
                        /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                        let _41 := and(/** @src 18:1130:1143  "input.tokenIn" */ read_from_calldatat_address(param_11), /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _30)
                        /// @src 18:1102:1186  "MintSyFromToken(msg.sender, input.tokenIn, SY, receiver, input.netTokenIn, netSyOut)"
                        let _42 := /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(64)
                        /// @src 18:1102:1186  "MintSyFromToken(msg.sender, input.tokenIn, SY, receiver, input.netTokenIn, netSyOut)"
                        log4(_42, sub(abi_encode_address_uint256_uint256(_42, param_8, value, var_netSyOut), _42), 0x71c7a44161eb32e4640f6c8f0586db5f1d2e03306e2c63bb2e0f7cd0a8fc690c, /** @src 19:897:907  "msg.sender" */ caller(), /** @src 18:1102:1186  "MintSyFromToken(msg.sender, input.tokenIn, SY, receiver, input.netTokenIn, netSyOut)" */ _41, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ and(/** @src 18:1102:1186  "MintSyFromToken(msg.sender, input.tokenIn, SY, receiver, input.netTokenIn, netSyOut)" */ param_9, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _30))
                        let memPos_2 := mload(64)
                        mstore(memPos_2, var_netSyOut)
                        return(memPos_2, /** @src 19:909:925  "input.netTokenIn" */ _29)
                    }
                    case /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0x59be67bf {
                        if callvalue() { revert(0, 0) }
                        let param_12, param_13, param_14, param_15 := abi_decode_addresst_addresst_uint256t_struct_TokenInput_calldata(calldatasize())
                        let _43 := sub(shl(160, 1), 1)
                        let _44 := and(/** @src 18:3090:3106  "IPYieldToken(YT)" */ param_13, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _43)
                        /// @src 18:3090:3111  "IPYieldToken(YT).SY()"
                        let _45 := /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(64)
                        /// @src 18:3090:3111  "IPYieldToken(YT).SY()"
                        mstore(_45, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ shl(224, 0xafd27bf5))
                        /// @src 18:3090:3111  "IPYieldToken(YT).SY()"
                        let _46 := 32
                        let _47 := staticcall(gas(), _44, _45, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 4, /** @src 18:3090:3111  "IPYieldToken(YT).SY()" */ _45, _46)
                        if iszero(_47)
                        {
                            /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                            let pos_7 := mload(64)
                            returndatacopy(pos_7, 0, returndatasize())
                            revert(pos_7, returndatasize())
                        }
                        /// @src 18:3090:3111  "IPYieldToken(YT).SY()"
                        let expr_15 := /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0
                        /// @src 18:3090:3111  "IPYieldToken(YT).SY()"
                        if _47
                        {
                            let _48 := _46
                            if gt(_46, returndatasize()) { _48 := returndatasize() }
                            finalize_allocation(_45, _48)
                            expr_15 := abi_decode_address_fromMemory(_45, add(_45, _48))
                        }
                        /// @src 18:3160:3181  "_syOrBulk(SY, output)"
                        let _49 := fun_syOrBulk(expr_15, param_15)
                        /// @src 19:4020:4041  "IPYieldToken(YT).PT()"
                        let _50 := /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(64)
                        /// @src 19:4020:4041  "IPYieldToken(YT).PT()"
                        mstore(_50, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ shl(226, 0x36501cf5))
                        /// @src 19:4020:4041  "IPYieldToken(YT).PT()"
                        let _51 := staticcall(gas(), _44, _50, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 4, /** @src 19:4020:4041  "IPYieldToken(YT).PT()" */ _50, /** @src 18:3090:3111  "IPYieldToken(YT).SY()" */ _46)
                        /// @src 19:4020:4041  "IPYieldToken(YT).PT()"
                        if iszero(_51)
                        {
                            /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                            let pos_8 := mload(64)
                            returndatacopy(pos_8, 0, returndatasize())
                            revert(pos_8, returndatasize())
                        }
                        /// @src 19:4020:4041  "IPYieldToken(YT).PT()"
                        let expr_16 := /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0
                        /// @src 19:4020:4041  "IPYieldToken(YT).PT()"
                        if _51
                        {
                            let _52 := /** @src 18:3090:3111  "IPYieldToken(YT).SY()" */ _46
                            /// @src 19:4020:4041  "IPYieldToken(YT).PT()"
                            if gt(/** @src 18:3090:3111  "IPYieldToken(YT).SY()" */ _46, /** @src 19:4020:4041  "IPYieldToken(YT).PT()" */ returndatasize()) { _52 := returndatasize() }
                            finalize_allocation(_50, _52)
                            expr_16 := abi_decode_address_fromMemory(_50, add(_50, _52))
                        }
                        /// @src 6:871:882  "amount != 0"
                        let _53 := iszero(iszero(param_14))
                        /// @src 6:867:924  "if (amount != 0) token.safeTransferFrom(from, to, amount)"
                        if /** @src 6:871:882  "amount != 0" */ _53
                        /// @src 6:867:924  "if (amount != 0) token.safeTransferFrom(from, to, amount)"
                        {
                            /// @src 6:917:923  "amount"
                            fun_safeTransferFrom(/** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ and(/** @src 19:4066:4076  "IERC20(PT)" */ expr_16, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _43), /** @src 19:4078:4088  "msg.sender" */ caller(), /** @src 6:917:923  "amount" */ param_13, param_14)
                        }
                        /// @src 19:4135:4163  "IPYieldToken(YT).isExpired()"
                        let _54 := /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(64)
                        /// @src 19:4135:4163  "IPYieldToken(YT).isExpired()"
                        mstore(_54, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ shl(226, 0x0bc4ed83))
                        /// @src 19:4135:4163  "IPYieldToken(YT).isExpired()"
                        let _55 := staticcall(gas(), _44, _54, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 4, /** @src 19:4135:4163  "IPYieldToken(YT).isExpired()" */ _54, /** @src 18:3090:3111  "IPYieldToken(YT).SY()" */ _46)
                        /// @src 19:4135:4163  "IPYieldToken(YT).isExpired()"
                        if iszero(_55)
                        {
                            /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                            let pos_9 := mload(64)
                            returndatacopy(pos_9, 0, returndatasize())
                            revert(pos_9, returndatasize())
                        }
                        /// @src 19:4135:4163  "IPYieldToken(YT).isExpired()"
                        let expr_17 := /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0
                        /// @src 19:4135:4163  "IPYieldToken(YT).isExpired()"
                        if _55
                        {
                            let _56 := /** @src 18:3090:3111  "IPYieldToken(YT).SY()" */ _46
                            /// @src 19:4135:4163  "IPYieldToken(YT).isExpired()"
                            if gt(/** @src 18:3090:3111  "IPYieldToken(YT).SY()" */ _46, /** @src 19:4135:4163  "IPYieldToken(YT).isExpired()" */ returndatasize()) { _56 := returndatasize() }
                            finalize_allocation(_54, _56)
                            expr_17 := abi_decode_bool_fromMemory(_54, add(_54, _56))
                        }
                        /// @src 19:4174:4242  "if (needToBurnYt) _transferFrom(IERC20(YT), msg.sender, YT, netPyIn)"
                        if /** @src 19:4134:4163  "!IPYieldToken(YT).isExpired()" */ iszero(expr_17)
                        /// @src 19:4174:4242  "if (needToBurnYt) _transferFrom(IERC20(YT), msg.sender, YT, netPyIn)"
                        {
                            /// @src 6:867:924  "if (amount != 0) token.safeTransferFrom(from, to, amount)"
                            if /** @src 6:871:882  "amount != 0" */ _53
                            /// @src 6:867:924  "if (amount != 0) token.safeTransferFrom(from, to, amount)"
                            {
                                /// @src 6:917:923  "amount"
                                fun_safeTransferFrom(_44, /** @src 19:4078:4088  "msg.sender" */ caller(), /** @src 6:917:923  "amount" */ param_13, param_14)
                            }
                        }
                        /// @src 19:4264:4299  "IPYieldToken(YT).redeemPY(receiver)"
                        let _57 := /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(64)
                        /// @src 19:4264:4299  "IPYieldToken(YT).redeemPY(receiver)"
                        mstore(_57, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ shl(224, 0xbcb7ea5d))
                        mstore(/** @src 19:4264:4299  "IPYieldToken(YT).redeemPY(receiver)" */ add(_57, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 4), and(_49, _43))
                        /// @src 19:4264:4299  "IPYieldToken(YT).redeemPY(receiver)"
                        let _58 := call(gas(), _44, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0, /** @src 19:4264:4299  "IPYieldToken(YT).redeemPY(receiver)" */ _57, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 36, /** @src 19:4264:4299  "IPYieldToken(YT).redeemPY(receiver)" */ _57, /** @src 18:3090:3111  "IPYieldToken(YT).SY()" */ _46)
                        /// @src 19:4264:4299  "IPYieldToken(YT).redeemPY(receiver)"
                        if iszero(_58)
                        {
                            /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                            let pos_10 := mload(64)
                            returndatacopy(pos_10, 0, returndatasize())
                            revert(pos_10, returndatasize())
                        }
                        /// @src 19:4264:4299  "IPYieldToken(YT).redeemPY(receiver)"
                        let expr_18 := /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0
                        /// @src 19:4264:4299  "IPYieldToken(YT).redeemPY(receiver)"
                        if _58
                        {
                            let _59 := /** @src 18:3090:3111  "IPYieldToken(YT).SY()" */ _46
                            /// @src 19:4264:4299  "IPYieldToken(YT).redeemPY(receiver)"
                            if gt(/** @src 18:3090:3111  "IPYieldToken(YT).SY()" */ _46, /** @src 19:4264:4299  "IPYieldToken(YT).redeemPY(receiver)" */ returndatasize()) { _59 := returndatasize() }
                            finalize_allocation(_57, _59)
                            /// @src 6:315:325  "address(0)"
                            if slt(sub(/** @src 19:4264:4299  "IPYieldToken(YT).redeemPY(receiver)" */ add(_57, _59), /** @src 6:315:325  "address(0)" */ _57), /** @src 18:3090:3111  "IPYieldToken(YT).SY()" */ _46)
                            /// @src 6:315:325  "address(0)"
                            {
                                /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                                revert(0, 0)
                            }
                            /// @src 19:4264:4299  "IPYieldToken(YT).redeemPY(receiver)"
                            expr_18 := /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(_57)
                        }
                        /// @src 19:4309:4391  "if (netSyOut < minSyOut) revert Errors.RouterInsufficientSyOut(netSyOut, minSyOut)"
                        if /** @src 19:4313:4332  "netSyOut < minSyOut" */ lt(expr_18, /** @src 18:3196:3197  "1" */ 0x01)
                        /// @src 19:4309:4391  "if (netSyOut < minSyOut) revert Errors.RouterInsufficientSyOut(netSyOut, minSyOut)"
                        {
                            /// @src 19:4341:4391  "Errors.RouterInsufficientSyOut(netSyOut, minSyOut)"
                            let _60 := /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(64)
                            /// @src 19:4341:4391  "Errors.RouterInsufficientSyOut(netSyOut, minSyOut)"
                            mstore(_60, shl(225, 0x05221cf3))
                            /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                            mstore(/** @src 19:4341:4391  "Errors.RouterInsufficientSyOut(netSyOut, minSyOut)" */ add(_60, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 4), expr_18)
                            mstore(add(/** @src 19:4341:4391  "Errors.RouterInsufficientSyOut(netSyOut, minSyOut)" */ _60, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 36), /** @src 18:3196:3197  "1" */ 0x01)
                            /// @src 19:4341:4391  "Errors.RouterInsufficientSyOut(netSyOut, minSyOut)"
                            revert(_60, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 68)
                        }
                        /// @src 18:3222:3282  "_redeemSyToToken(receiver, SY, netSyToRedeem, output, false)"
                        let var_netTokenOut := /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0
                        /// @src 19:2180:2200  "output.tokenRedeemSy"
                        let _61 := add(param_15, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 64)
                        /// @src 19:2180:2200  "output.tokenRedeemSy"
                        let expr_19 := read_from_calldatat_address(_61)
                        /// @src 19:2180:2219  "output.tokenRedeemSy != output.tokenOut"
                        let expr_20 := iszero(eq(/** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ and(/** @src 19:2180:2219  "output.tokenRedeemSy != output.tokenOut" */ expr_19, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _43), and(/** @src 19:2204:2219  "output.tokenOut" */ read_from_calldatat_address(param_15), /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _43)))
                        /// @src 19:2256:2294  "requireSwap ? address(this) : receiver"
                        let expr_21 := /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0
                        /// @src 19:2256:2294  "requireSwap ? address(this) : receiver"
                        switch expr_20
                        case 0 { expr_21 := param_12 }
                        default {
                            expr_21 := /** @src 19:2278:2282  "this" */ address()
                        }
                        /// @src 19:2304:2328  "uint256 netTokenRedeemed"
                        let var_netTokenRedeemed := /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0
                        /// @src 19:2343:2354  "output.bulk"
                        let _62 := add(param_15, 96)
                        /// @src 19:2339:2804  "if (output.bulk != address(0)) {..."
                        switch /** @src 19:2343:2368  "output.bulk != address(0)" */ iszero(iszero(/** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ and(/** @src 19:2343:2354  "output.bulk" */ read_from_calldatat_address(_62), /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _43)))
                        case /** @src 19:2339:2804  "if (output.bulk != address(0)) {..." */ 0 {
                            /// @src 19:2718:2738  "output.tokenRedeemSy"
                            let expr_22 := read_from_calldatat_address(_61)
                            /// @src 19:2612:2793  "IStandardizedYield(SY).redeem(..."
                            let _63 := /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(64)
                            /// @src 19:2612:2793  "IStandardizedYield(SY).redeem(..."
                            mstore(_63, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ shl(224, 0x769f8e5d))
                            mstore(/** @src 19:2612:2793  "IStandardizedYield(SY).redeem(..." */ add(_63, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 4), and(expr_21, _43))
                            mstore(add(/** @src 19:2612:2793  "IStandardizedYield(SY).redeem(..." */ _63, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 36), expr_18)
                            mstore(add(/** @src 19:2612:2793  "IStandardizedYield(SY).redeem(..." */ _63, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 68), and(expr_22, _43))
                            mstore(add(/** @src 19:2612:2793  "IStandardizedYield(SY).redeem(..." */ _63, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 100), 0)
                            mstore(add(/** @src 19:2612:2793  "IStandardizedYield(SY).redeem(..." */ _63, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 132), /** @src 18:3196:3197  "1" */ 0x01)
                            /// @src 19:2612:2793  "IStandardizedYield(SY).redeem(..."
                            let _64 := call(gas(), /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ and(/** @src 19:2612:2634  "IStandardizedYield(SY)" */ expr_15, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _43), 0, /** @src 19:2612:2793  "IStandardizedYield(SY).redeem(..." */ _63, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 164, /** @src 19:2612:2793  "IStandardizedYield(SY).redeem(..." */ _63, /** @src 18:3090:3111  "IPYieldToken(YT).SY()" */ _46)
                            /// @src 19:2612:2793  "IStandardizedYield(SY).redeem(..."
                            if iszero(_64)
                            {
                                /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                                let pos_11 := mload(64)
                                returndatacopy(pos_11, 0, returndatasize())
                                revert(pos_11, returndatasize())
                            }
                            /// @src 19:2612:2793  "IStandardizedYield(SY).redeem(..."
                            let expr_23 := /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0
                            /// @src 19:2612:2793  "IStandardizedYield(SY).redeem(..."
                            if _64
                            {
                                let _65 := /** @src 18:3090:3111  "IPYieldToken(YT).SY()" */ _46
                                /// @src 19:2612:2793  "IStandardizedYield(SY).redeem(..."
                                if gt(/** @src 18:3090:3111  "IPYieldToken(YT).SY()" */ _46, /** @src 19:2612:2793  "IStandardizedYield(SY).redeem(..." */ returndatasize()) { _65 := returndatasize() }
                                finalize_allocation(_63, _65)
                                /// @src 6:315:325  "address(0)"
                                if slt(sub(/** @src 19:2612:2793  "IStandardizedYield(SY).redeem(..." */ add(_63, _65), /** @src 6:315:325  "address(0)" */ _63), /** @src 18:3090:3111  "IPYieldToken(YT).SY()" */ _46)
                                /// @src 6:315:325  "address(0)"
                                {
                                    /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                                    revert(0, 0)
                                }
                                /// @src 19:2612:2793  "IStandardizedYield(SY).redeem(..."
                                expr_23 := /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(_63)
                            }
                            /// @src 19:2593:2793  "netTokenRedeemed = IStandardizedYield(SY).redeem(..."
                            var_netTokenRedeemed := expr_23
                        }
                        default /// @src 19:2339:2804  "if (output.bulk != address(0)) {..."
                        {
                            /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                            let _66 := and(/** @src 19:2416:2427  "output.bulk" */ read_from_calldatat_address(_62), /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _43)
                            /// @src 19:2403:2562  "IPBulkSeller(output.bulk).swapExactSyForToken(..."
                            let _67 := /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(64)
                            /// @src 19:2403:2562  "IPBulkSeller(output.bulk).swapExactSyForToken(..."
                            mstore(_67, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ shl(225, 0x41fadbb3))
                            mstore(/** @src 19:2403:2562  "IPBulkSeller(output.bulk).swapExactSyForToken(..." */ add(_67, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 4), and(expr_21, _43))
                            mstore(add(/** @src 19:2403:2562  "IPBulkSeller(output.bulk).swapExactSyForToken(..." */ _67, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 36), expr_18)
                            mstore(add(/** @src 19:2403:2562  "IPBulkSeller(output.bulk).swapExactSyForToken(..." */ _67, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 68), 0)
                            mstore(add(/** @src 19:2403:2562  "IPBulkSeller(output.bulk).swapExactSyForToken(..." */ _67, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 100), /** @src 18:3196:3197  "1" */ 0x01)
                            /// @src 19:2403:2562  "IPBulkSeller(output.bulk).swapExactSyForToken(..."
                            let _68 := call(gas(), _66, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0, /** @src 19:2403:2562  "IPBulkSeller(output.bulk).swapExactSyForToken(..." */ _67, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 132, /** @src 19:2403:2562  "IPBulkSeller(output.bulk).swapExactSyForToken(..." */ _67, /** @src 18:3090:3111  "IPYieldToken(YT).SY()" */ _46)
                            /// @src 19:2403:2562  "IPBulkSeller(output.bulk).swapExactSyForToken(..."
                            if iszero(_68)
                            {
                                /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                                let pos_12 := mload(64)
                                returndatacopy(pos_12, 0, returndatasize())
                                revert(pos_12, returndatasize())
                            }
                            /// @src 19:2403:2562  "IPBulkSeller(output.bulk).swapExactSyForToken(..."
                            let expr_24 := /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0
                            /// @src 19:2403:2562  "IPBulkSeller(output.bulk).swapExactSyForToken(..."
                            if _68
                            {
                                let _69 := /** @src 18:3090:3111  "IPYieldToken(YT).SY()" */ _46
                                /// @src 19:2403:2562  "IPBulkSeller(output.bulk).swapExactSyForToken(..."
                                if gt(/** @src 18:3090:3111  "IPYieldToken(YT).SY()" */ _46, /** @src 19:2403:2562  "IPBulkSeller(output.bulk).swapExactSyForToken(..." */ returndatasize()) { _69 := returndatasize() }
                                finalize_allocation(_67, _69)
                                /// @src 6:315:325  "address(0)"
                                if slt(sub(/** @src 19:2403:2562  "IPBulkSeller(output.bulk).swapExactSyForToken(..." */ add(_67, _69), /** @src 6:315:325  "address(0)" */ _67), /** @src 18:3090:3111  "IPYieldToken(YT).SY()" */ _46)
                                /// @src 6:315:325  "address(0)"
                                {
                                    /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                                    revert(0, 0)
                                }
                                /// @src 19:2403:2562  "IPBulkSeller(output.bulk).swapExactSyForToken(..."
                                expr_24 := /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(_67)
                            }
                            /// @src 19:2384:2562  "netTokenRedeemed = IPBulkSeller(output.bulk).swapExactSyForToken(..."
                            var_netTokenRedeemed := expr_24
                        }
                        /// @src 19:2814:3208  "if (requireSwap) {..."
                        switch expr_20
                        case 0 {
                            /// @src 19:3167:3197  "netTokenOut = netTokenRedeemed"
                            var_netTokenOut := var_netTokenRedeemed
                        }
                        default /// @src 19:2814:3208  "if (requireSwap) {..."
                        {
                            /// @src 19:2873:2893  "output.tokenRedeemSy"
                            let expr_25 := read_from_calldatat_address(_61)
                            /// @src 19:2945:2963  "output.kyberRouter"
                            let expr_26 := read_from_calldatat_address(add(param_15, 128))
                            /// @src 19:2981:2997  "output.kybercall"
                            let expr_offset_1, expr_length_1 := access_calldata_tail_bytes_calldata(param_15, add(param_15, 160))
                            fun_kyberswap(expr_25, var_netTokenRedeemed, expr_26, expr_offset_1, expr_length_1)
                            /// @src 19:3026:3069  "netTokenOut = _selfBalance(output.tokenOut)"
                            var_netTokenOut := /** @src 19:3040:3069  "_selfBalance(output.tokenOut)" */ fun_selfBalance(/** @src 19:3053:3068  "output.tokenOut" */ read_from_calldatat_address(param_15))
                            /// @src 19:3124:3135  "netTokenOut"
                            fun_transferOut(/** @src 19:3097:3112  "output.tokenOut" */ read_from_calldatat_address(param_15), /** @src 19:3124:3135  "netTokenOut" */ param_12, var_netTokenOut)
                        }
                        /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                        let value_1 := calldataload(/** @src 19:3236:3254  "output.minTokenOut" */ add(param_15, /** @src 18:3090:3111  "IPYieldToken(YT).SY()" */ _46))
                        /// @src 19:3218:3354  "if (netTokenOut < output.minTokenOut) {..."
                        if /** @src 19:3222:3254  "netTokenOut < output.minTokenOut" */ lt(var_netTokenOut, value_1)
                        /// @src 19:3218:3354  "if (netTokenOut < output.minTokenOut) {..."
                        {
                            /// @src 19:3277:3343  "Errors.RouterInsufficientTokenOut(netTokenOut, output.minTokenOut)"
                            let _70 := /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(64)
                            /// @src 19:3277:3343  "Errors.RouterInsufficientTokenOut(netTokenOut, output.minTokenOut)"
                            mstore(_70, shl(224, 0xc5b5576d))
                            /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                            mstore(/** @src 19:3277:3343  "Errors.RouterInsufficientTokenOut(netTokenOut, output.minTokenOut)" */ add(_70, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 4), var_netTokenOut)
                            mstore(add(/** @src 19:3277:3343  "Errors.RouterInsufficientTokenOut(netTokenOut, output.minTokenOut)" */ _70, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 36), value_1)
                            /// @src 19:3277:3343  "Errors.RouterInsufficientTokenOut(netTokenOut, output.minTokenOut)"
                            revert(_70, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 68)
                        }
                        let _71 := and(/** @src 18:3326:3341  "output.tokenOut" */ read_from_calldatat_address(param_15), /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _43)
                        /// @src 18:3298:3378  "RedeemPyToToken(msg.sender, output.tokenOut, YT, receiver, netPyIn, netTokenOut)"
                        let _72 := /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(64)
                        /// @src 18:3298:3378  "RedeemPyToToken(msg.sender, output.tokenOut, YT, receiver, netPyIn, netTokenOut)"
                        log4(_72, sub(abi_encode_address_uint256_uint256(_72, param_12, param_14, var_netTokenOut), _72), 0xbc9f07701b0532bc31f2fe7a59b23aa94ae7e58ae26437b01b3440c5903b1bf1, /** @src 19:4078:4088  "msg.sender" */ caller(), /** @src 18:3298:3378  "RedeemPyToToken(msg.sender, output.tokenOut, YT, receiver, netPyIn, netTokenOut)" */ _71, _44)
                        /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                        let memPos_3 := mload(64)
                        mstore(memPos_3, var_netTokenOut)
                        return(memPos_3, /** @src 18:3090:3111  "IPYieldToken(YT).SY()" */ _46)
                    }
                    case /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0x7298779b {
                        let param_16, param_17, param_18, param_19 := abi_decode_addresst_addresst_uint256t_struct_TokenInput_calldata(calldatasize())
                        let _73 := sub(shl(160, 1), 1)
                        let _74 := and(/** @src 18:2319:2335  "IPYieldToken(YT)" */ param_17, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _73)
                        /// @src 18:2319:2340  "IPYieldToken(YT).SY()"
                        let _75 := /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(64)
                        /// @src 18:2319:2340  "IPYieldToken(YT).SY()"
                        mstore(_75, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ shl(224, 0xafd27bf5))
                        /// @src 18:2319:2340  "IPYieldToken(YT).SY()"
                        let _76 := 32
                        let _77 := staticcall(gas(), _74, _75, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 4, /** @src 18:2319:2340  "IPYieldToken(YT).SY()" */ _75, _76)
                        if iszero(_77)
                        {
                            /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                            let pos_13 := mload(64)
                            returndatacopy(pos_13, 0, returndatasize())
                            revert(pos_13, returndatasize())
                        }
                        /// @src 18:2319:2340  "IPYieldToken(YT).SY()"
                        let expr_27 := /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0
                        /// @src 18:2319:2340  "IPYieldToken(YT).SY()"
                        if _77
                        {
                            let _78 := _76
                            if gt(_76, returndatasize()) { _78 := returndatasize() }
                            finalize_allocation(_75, _78)
                            expr_27 := abi_decode_address_fromMemory(_75, add(_75, _78))
                        }
                        /// @src 19:882:895  "input.tokenIn"
                        let expr_28 := read_from_calldatat_address(param_19)
                        /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                        let value_2 := calldataload(/** @src 19:909:925  "input.netTokenIn" */ add(param_19, /** @src 18:2319:2340  "IPYieldToken(YT).SY()" */ _76))
                        /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                        let _79 := and(/** @src 6:566:581  "token == NATIVE" */ expr_28, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _73)
                        /// @src 6:562:718  "if (token == NATIVE) require(msg.value == amount, \"eth mismatch\");..."
                        switch /** @src 6:566:581  "token == NATIVE" */ iszero(/** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _79)
                        case /** @src 6:562:718  "if (token == NATIVE) require(msg.value == amount, \"eth mismatch\");..." */ 0 {
                            /// @src 6:642:718  "if (amount != 0) IERC20(token).safeTransferFrom(from, address(this), amount)"
                            if /** @src 6:646:657  "amount != 0" */ iszero(iszero(value_2))
                            /// @src 6:642:718  "if (amount != 0) IERC20(token).safeTransferFrom(from, address(this), amount)"
                            {
                                /// @src 6:711:717  "amount"
                                fun_safeTransferFrom(_79, /** @src 19:897:907  "msg.sender" */ caller(), /** @src 6:704:708  "this" */ address(), /** @src 6:711:717  "amount" */ value_2)
                            }
                        }
                        default /// @src 6:562:718  "if (token == NATIVE) require(msg.value == amount, \"eth mismatch\");..."
                        {
                            /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                            if iszero(/** @src 6:591:610  "msg.value == amount" */ eq(/** @src 6:591:600  "msg.value" */ callvalue(), /** @src 6:591:610  "msg.value == amount" */ value_2))
                            /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                            {
                                let memPtr_1 := mload(64)
                                mstore(memPtr_1, shl(229, 4594637))
                                mstore(add(memPtr_1, 4), /** @src 18:2319:2340  "IPYieldToken(YT).SY()" */ _76)
                                /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                                mstore(add(memPtr_1, 36), 12)
                                mstore(add(memPtr_1, 68), "eth mismatch")
                                revert(memPtr_1, 100)
                            }
                        }
                        /// @src 19:956:969  "input.tokenIn"
                        let expr_29 := read_from_calldatat_address(param_19)
                        /// @src 19:973:990  "input.tokenMintSy"
                        let _80 := add(param_19, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 64)
                        /// @src 19:956:990  "input.tokenIn != input.tokenMintSy"
                        let expr_30 := iszero(eq(/** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ and(/** @src 19:956:990  "input.tokenIn != input.tokenMintSy" */ expr_29, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _73), and(/** @src 19:973:990  "input.tokenMintSy" */ read_from_calldatat_address(_80), /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _73)))
                        /// @src 19:1001:1023  "uint256 netTokenMintSy"
                        let var_netTokenMintSy_1 := /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0
                        /// @src 19:1034:1281  "if (requireSwap) {..."
                        switch expr_30
                        case 0 {
                            /// @src 19:1237:1270  "netTokenMintSy = input.netTokenIn"
                            var_netTokenMintSy_1 := value_2
                        }
                        default /// @src 19:1034:1281  "if (requireSwap) {..."
                        {
                            /// @src 19:1076:1089  "input.tokenIn"
                            let expr_31 := read_from_calldatat_address(param_19)
                            /// @src 19:1109:1126  "input.kyberRouter"
                            let expr_32 := read_from_calldatat_address(add(param_19, 128))
                            /// @src 19:1128:1143  "input.kybercall"
                            let expr_offset_2, expr_length_2 := access_calldata_tail_bytes_calldata(param_19, add(param_19, 160))
                            fun_kyberswap(expr_31, value_2, expr_32, expr_offset_2, expr_length_2)
                            /// @src 19:1158:1206  "netTokenMintSy = _selfBalance(input.tokenMintSy)"
                            var_netTokenMintSy_1 := /** @src 19:1175:1206  "_selfBalance(input.tokenMintSy)" */ fun_selfBalance(/** @src 19:1188:1205  "input.tokenMintSy" */ read_from_calldatat_address(_80))
                        }
                        /// @src 19:1311:1338  "input.tokenMintSy == NATIVE"
                        let expr_33 := iszero(/** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ and(/** @src 19:1311:1328  "input.tokenMintSy" */ read_from_calldatat_address(_80), /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _73))
                        /// @src 19:1311:1359  "input.tokenMintSy == NATIVE ? netTokenMintSy : 0"
                        let expr_34 := /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0
                        /// @src 19:1311:1359  "input.tokenMintSy == NATIVE ? netTokenMintSy : 0"
                        switch expr_33
                        case 0 {
                            expr_34 := /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0
                        }
                        default /// @src 19:1311:1359  "input.tokenMintSy == NATIVE ? netTokenMintSy : 0"
                        {
                            expr_34 := var_netTokenMintSy_1
                        }
                        /// @src 19:1374:1384  "input.bulk"
                        let _81 := add(param_19, 96)
                        /// @src 19:1370:1823  "if (input.bulk != address(0)) {..."
                        switch /** @src 19:1374:1398  "input.bulk != address(0)" */ iszero(iszero(/** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ and(/** @src 19:1374:1384  "input.bulk" */ read_from_calldatat_address(_81), /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _73)))
                        case /** @src 19:1370:1823  "if (input.bulk != address(0)) {..." */ 0 {
                            /// @src 19:1723:1740  "input.tokenMintSy"
                            let expr_35 := read_from_calldatat_address(_80)
                            /// @src 19:1629:1812  "IStandardizedYield(SY).deposit{ value: netNative }(..."
                            let _82 := /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(64)
                            /// @src 19:1629:1812  "IStandardizedYield(SY).deposit{ value: netNative }(..."
                            mstore(_82, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ shl(224, 0x20e8c565))
                            mstore(/** @src 19:1629:1812  "IStandardizedYield(SY).deposit{ value: netNative }(..." */ add(_82, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 4), _74)
                            mstore(/** @src 6:315:325  "address(0)" */ add(/** @src 19:1629:1812  "IStandardizedYield(SY).deposit{ value: netNative }(..." */ _82, /** @src 6:315:325  "address(0)" */ 36), /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ and(expr_35, _73))
                            mstore(/** @src 6:315:325  "address(0)" */ add(/** @src 19:1629:1812  "IStandardizedYield(SY).deposit{ value: netNative }(..." */ _82, /** @src 6:315:325  "address(0)" */ 68), /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ var_netTokenMintSy_1)
                            mstore(/** @src 6:315:325  "address(0)" */ add(/** @src 19:1629:1812  "IStandardizedYield(SY).deposit{ value: netNative }(..." */ _82, /** @src 6:315:325  "address(0)" */ 100), /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0)
                            /// @src 19:1629:1812  "IStandardizedYield(SY).deposit{ value: netNative }(..."
                            let _83 := call(gas(), /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ and(/** @src 19:1629:1651  "IStandardizedYield(SY)" */ expr_27, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _73), /** @src 19:1629:1812  "IStandardizedYield(SY).deposit{ value: netNative }(..." */ expr_34, _82, /** @src 6:315:325  "address(0)" */ 132, /** @src 19:1629:1812  "IStandardizedYield(SY).deposit{ value: netNative }(..." */ _82, /** @src 18:2319:2340  "IPYieldToken(YT).SY()" */ _76)
                            /// @src 19:1629:1812  "IStandardizedYield(SY).deposit{ value: netNative }(..."
                            if iszero(_83)
                            {
                                /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                                let pos_14 := mload(64)
                                returndatacopy(pos_14, 0, returndatasize())
                                revert(pos_14, returndatasize())
                            }
                            /// @src 19:1629:1812  "IStandardizedYield(SY).deposit{ value: netNative }(..."
                            if _83
                            {
                                let _84 := /** @src 18:2319:2340  "IPYieldToken(YT).SY()" */ _76
                                /// @src 19:1629:1812  "IStandardizedYield(SY).deposit{ value: netNative }(..."
                                if gt(/** @src 18:2319:2340  "IPYieldToken(YT).SY()" */ _76, /** @src 19:1629:1812  "IStandardizedYield(SY).deposit{ value: netNative }(..." */ returndatasize()) { _84 := returndatasize() }
                                finalize_allocation(_82, _84)
                                /// @src 6:315:325  "address(0)"
                                if slt(sub(/** @src 19:1629:1812  "IStandardizedYield(SY).deposit{ value: netNative }(..." */ add(_82, _84), /** @src 6:315:325  "address(0)" */ _82), /** @src 18:2319:2340  "IPYieldToken(YT).SY()" */ _76)
                                /// @src 6:315:325  "address(0)"
                                {
                                    /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                                    revert(0, 0)
                                }
                            }
                        }
                        default /// @src 19:1370:1823  "if (input.bulk != address(0)) {..."
                        {
                            /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                            let _85 := and(/** @src 19:1438:1448  "input.bulk" */ read_from_calldatat_address(_81), /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _73)
                            /// @src 19:1425:1587  "IPBulkSeller(input.bulk).swapExactTokenForSy{ value: netNative }(..."
                            let _86 := /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(64)
                            /// @src 19:1425:1587  "IPBulkSeller(input.bulk).swapExactTokenForSy{ value: netNative }(..."
                            mstore(_86, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ shl(228, 0x0b276707))
                            mstore(/** @src 19:1425:1587  "IPBulkSeller(input.bulk).swapExactTokenForSy{ value: netNative }(..." */ add(_86, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 4), _74)
                            mstore(add(/** @src 19:1425:1587  "IPBulkSeller(input.bulk).swapExactTokenForSy{ value: netNative }(..." */ _86, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 36), var_netTokenMintSy_1)
                            mstore(add(/** @src 19:1425:1587  "IPBulkSeller(input.bulk).swapExactTokenForSy{ value: netNative }(..." */ _86, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 68), 0)
                            /// @src 19:1425:1587  "IPBulkSeller(input.bulk).swapExactTokenForSy{ value: netNative }(..."
                            let _87 := call(gas(), _85, expr_34, _86, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 100, /** @src 19:1425:1587  "IPBulkSeller(input.bulk).swapExactTokenForSy{ value: netNative }(..." */ _86, /** @src 18:2319:2340  "IPYieldToken(YT).SY()" */ _76)
                            /// @src 19:1425:1587  "IPBulkSeller(input.bulk).swapExactTokenForSy{ value: netNative }(..."
                            if iszero(_87)
                            {
                                /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                                let pos_15 := mload(64)
                                returndatacopy(pos_15, 0, returndatasize())
                                revert(pos_15, returndatasize())
                            }
                            /// @src 19:1425:1587  "IPBulkSeller(input.bulk).swapExactTokenForSy{ value: netNative }(..."
                            if _87
                            {
                                let _88 := /** @src 18:2319:2340  "IPYieldToken(YT).SY()" */ _76
                                /// @src 19:1425:1587  "IPBulkSeller(input.bulk).swapExactTokenForSy{ value: netNative }(..."
                                if gt(/** @src 18:2319:2340  "IPYieldToken(YT).SY()" */ _76, /** @src 19:1425:1587  "IPBulkSeller(input.bulk).swapExactTokenForSy{ value: netNative }(..." */ returndatasize()) { _88 := returndatasize() }
                                finalize_allocation(_86, _88)
                                /// @src 6:315:325  "address(0)"
                                if slt(sub(/** @src 19:1425:1587  "IPBulkSeller(input.bulk).swapExactTokenForSy{ value: netNative }(..." */ add(_86, _88), /** @src 6:315:325  "address(0)" */ _86), /** @src 18:2319:2340  "IPYieldToken(YT).SY()" */ _76)
                                /// @src 6:315:325  "address(0)"
                                {
                                    /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                                    revert(0, 0)
                                }
                            }
                        }
                        /// @src 19:3687:3730  "IPYieldToken(YT).mintPY(receiver, receiver)"
                        let _89 := /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(64)
                        /// @src 19:3687:3730  "IPYieldToken(YT).mintPY(receiver, receiver)"
                        mstore(_89, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ shl(224, 0xdb74aa15))
                        let _90 := and(param_16, _73)
                        mstore(/** @src 19:3687:3730  "IPYieldToken(YT).mintPY(receiver, receiver)" */ add(_89, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 4), _90)
                        mstore(add(/** @src 19:3687:3730  "IPYieldToken(YT).mintPY(receiver, receiver)" */ _89, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 36), _90)
                        /// @src 19:3687:3730  "IPYieldToken(YT).mintPY(receiver, receiver)"
                        let _91 := call(gas(), _74, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0, /** @src 19:3687:3730  "IPYieldToken(YT).mintPY(receiver, receiver)" */ _89, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 68, /** @src 19:3687:3730  "IPYieldToken(YT).mintPY(receiver, receiver)" */ _89, /** @src 18:2319:2340  "IPYieldToken(YT).SY()" */ _76)
                        /// @src 19:3687:3730  "IPYieldToken(YT).mintPY(receiver, receiver)"
                        if iszero(_91)
                        {
                            /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                            let pos_16 := mload(64)
                            returndatacopy(pos_16, 0, returndatasize())
                            revert(pos_16, returndatasize())
                        }
                        /// @src 19:3687:3730  "IPYieldToken(YT).mintPY(receiver, receiver)"
                        let expr_36 := /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0
                        /// @src 19:3687:3730  "IPYieldToken(YT).mintPY(receiver, receiver)"
                        if _91
                        {
                            let _92 := /** @src 18:2319:2340  "IPYieldToken(YT).SY()" */ _76
                            /// @src 19:3687:3730  "IPYieldToken(YT).mintPY(receiver, receiver)"
                            if gt(/** @src 18:2319:2340  "IPYieldToken(YT).SY()" */ _76, /** @src 19:3687:3730  "IPYieldToken(YT).mintPY(receiver, receiver)" */ returndatasize()) { _92 := returndatasize() }
                            finalize_allocation(_89, _92)
                            /// @src 6:315:325  "address(0)"
                            if slt(sub(/** @src 19:3687:3730  "IPYieldToken(YT).mintPY(receiver, receiver)" */ add(_89, _92), /** @src 6:315:325  "address(0)" */ _89), /** @src 18:2319:2340  "IPYieldToken(YT).SY()" */ _76)
                            /// @src 6:315:325  "address(0)"
                            {
                                /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                                revert(0, 0)
                            }
                            /// @src 19:3687:3730  "IPYieldToken(YT).mintPY(receiver, receiver)"
                            expr_36 := /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(_89)
                        }
                        /// @src 19:3740:3822  "if (netPyOut < minPyOut) revert Errors.RouterInsufficientPYOut(netPyOut, minPyOut)"
                        if /** @src 19:3744:3763  "netPyOut < minPyOut" */ lt(expr_36, param_18)
                        /// @src 19:3740:3822  "if (netPyOut < minPyOut) revert Errors.RouterInsufficientPYOut(netPyOut, minPyOut)"
                        {
                            /// @src 19:3772:3822  "Errors.RouterInsufficientPYOut(netPyOut, minPyOut)"
                            let _93 := /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(64)
                            /// @src 19:3772:3822  "Errors.RouterInsufficientPYOut(netPyOut, minPyOut)"
                            mstore(_93, shl(224, 0xca935dfd))
                            /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                            mstore(/** @src 19:3772:3822  "Errors.RouterInsufficientPYOut(netPyOut, minPyOut)" */ add(_93, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 4), expr_36)
                            mstore(add(/** @src 19:3772:3822  "Errors.RouterInsufficientPYOut(netPyOut, minPyOut)" */ _93, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 36), param_18)
                            /// @src 19:3772:3822  "Errors.RouterInsufficientPYOut(netPyOut, minPyOut)"
                            revert(_93, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 68)
                        }
                        let _94 := and(/** @src 18:2533:2546  "input.tokenIn" */ read_from_calldatat_address(param_19), /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _73)
                        /// @src 18:2505:2589  "MintPyFromToken(msg.sender, input.tokenIn, YT, receiver, input.netTokenIn, netPyOut)"
                        let _95 := /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(64)
                        /// @src 18:2505:2589  "MintPyFromToken(msg.sender, input.tokenIn, YT, receiver, input.netTokenIn, netPyOut)"
                        log4(_95, sub(abi_encode_address_uint256_uint256(_95, param_16, value_2, expr_36), _95), 0xf586e656e1e436d9ca7c96e43cb793e47b685467d5d574a66efabb8501a333b8, /** @src 19:897:907  "msg.sender" */ caller(), /** @src 18:2505:2589  "MintPyFromToken(msg.sender, input.tokenIn, YT, receiver, input.netTokenIn, netPyOut)" */ _94, _74)
                        /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                        let memPos_4 := mload(64)
                        mstore(memPos_4, expr_36)
                        return(memPos_4, /** @src 18:2319:2340  "IPYieldToken(YT).SY()" */ _76)
                    }
                    case /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0xb6fece98 {
                        if callvalue() { revert(0, 0) }
                        let param_20, param_21, param_22, param_23 := abi_decode_addresst_addresst_uint256t_struct_TokenInput_calldata(calldatasize())
                        /// @src 18:1649:1702  "_redeemSyToToken(receiver, SY, netSyIn, output, true)"
                        let var_netTokenOut_1 := /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0
                        let _96 := sub(shl(160, 1), 1)
                        let _97 := and(/** @src 19:2085:2095  "IERC20(SY)" */ param_21, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _96)
                        /// @src 19:2109:2130  "_syOrBulk(SY, output)"
                        let _98 := fun_syOrBulk(param_21, param_23)
                        /// @src 6:867:924  "if (amount != 0) token.safeTransferFrom(from, to, amount)"
                        if /** @src 6:871:882  "amount != 0" */ iszero(iszero(param_22))
                        /// @src 6:867:924  "if (amount != 0) token.safeTransferFrom(from, to, amount)"
                        {
                            /// @src 6:917:923  "amount"
                            fun_safeTransferFrom(_97, /** @src 19:2097:2107  "msg.sender" */ caller(), /** @src 6:917:923  "amount" */ _98, param_22)
                        }
                        /// @src 19:2180:2200  "output.tokenRedeemSy"
                        let _99 := add(param_23, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 64)
                        /// @src 19:2180:2200  "output.tokenRedeemSy"
                        let expr_37 := read_from_calldatat_address(_99)
                        /// @src 19:2180:2219  "output.tokenRedeemSy != output.tokenOut"
                        let expr_38 := iszero(eq(/** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ and(/** @src 19:2180:2219  "output.tokenRedeemSy != output.tokenOut" */ expr_37, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _96), and(/** @src 19:2204:2219  "output.tokenOut" */ read_from_calldatat_address(param_23), /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _96)))
                        /// @src 19:2256:2294  "requireSwap ? address(this) : receiver"
                        let expr_39 := /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0
                        /// @src 19:2256:2294  "requireSwap ? address(this) : receiver"
                        switch expr_38
                        case 0 { expr_39 := param_20 }
                        default {
                            expr_39 := /** @src 19:2278:2282  "this" */ address()
                        }
                        /// @src 19:2304:2328  "uint256 netTokenRedeemed"
                        let var_netTokenRedeemed_1 := /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0
                        /// @src 19:2343:2354  "output.bulk"
                        let _100 := add(param_23, 96)
                        /// @src 19:2339:2804  "if (output.bulk != address(0)) {..."
                        switch /** @src 19:2343:2368  "output.bulk != address(0)" */ iszero(iszero(/** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ and(/** @src 19:2343:2354  "output.bulk" */ read_from_calldatat_address(_100), /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _96)))
                        case /** @src 19:2339:2804  "if (output.bulk != address(0)) {..." */ 0 {
                            /// @src 19:2718:2738  "output.tokenRedeemSy"
                            let expr_40 := read_from_calldatat_address(_99)
                            /// @src 19:2612:2793  "IStandardizedYield(SY).redeem(..."
                            let _101 := /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(64)
                            /// @src 19:2612:2793  "IStandardizedYield(SY).redeem(..."
                            mstore(_101, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ shl(224, 0x769f8e5d))
                            mstore(/** @src 19:2612:2793  "IStandardizedYield(SY).redeem(..." */ add(_101, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 4), and(expr_39, _96))
                            mstore(add(/** @src 19:2612:2793  "IStandardizedYield(SY).redeem(..." */ _101, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 36), param_22)
                            mstore(add(/** @src 19:2612:2793  "IStandardizedYield(SY).redeem(..." */ _101, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 68), and(expr_40, _96))
                            mstore(add(/** @src 19:2612:2793  "IStandardizedYield(SY).redeem(..." */ _101, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 100), 0)
                            mstore(add(/** @src 19:2612:2793  "IStandardizedYield(SY).redeem(..." */ _101, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 132), /** @src 18:1697:1701  "true" */ 0x01)
                            /// @src 19:2612:2793  "IStandardizedYield(SY).redeem(..."
                            let _102 := call(gas(), _97, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0, /** @src 19:2612:2793  "IStandardizedYield(SY).redeem(..." */ _101, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 164, /** @src 19:2612:2793  "IStandardizedYield(SY).redeem(..." */ _101, 32)
                            if iszero(_102)
                            {
                                /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                                let pos_17 := mload(64)
                                returndatacopy(pos_17, 0, returndatasize())
                                revert(pos_17, returndatasize())
                            }
                            /// @src 19:2612:2793  "IStandardizedYield(SY).redeem(..."
                            let expr_41 := /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0
                            /// @src 19:2612:2793  "IStandardizedYield(SY).redeem(..."
                            if _102
                            {
                                let _103 := 32
                                if gt(_103, returndatasize()) { _103 := returndatasize() }
                                finalize_allocation(_101, _103)
                                /// @src 6:315:325  "address(0)"
                                if slt(sub(/** @src 19:2612:2793  "IStandardizedYield(SY).redeem(..." */ add(_101, _103), /** @src 6:315:325  "address(0)" */ _101), /** @src 19:2612:2793  "IStandardizedYield(SY).redeem(..." */ 32)
                                /// @src 6:315:325  "address(0)"
                                {
                                    /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                                    revert(0, 0)
                                }
                                /// @src 19:2612:2793  "IStandardizedYield(SY).redeem(..."
                                expr_41 := /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(_101)
                            }
                            /// @src 19:2593:2793  "netTokenRedeemed = IStandardizedYield(SY).redeem(..."
                            var_netTokenRedeemed_1 := expr_41
                        }
                        default /// @src 19:2339:2804  "if (output.bulk != address(0)) {..."
                        {
                            /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                            let _104 := and(/** @src 19:2416:2427  "output.bulk" */ read_from_calldatat_address(_100), /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _96)
                            /// @src 19:2403:2562  "IPBulkSeller(output.bulk).swapExactSyForToken(..."
                            let _105 := /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(64)
                            /// @src 19:2403:2562  "IPBulkSeller(output.bulk).swapExactSyForToken(..."
                            mstore(_105, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ shl(225, 0x41fadbb3))
                            mstore(/** @src 19:2403:2562  "IPBulkSeller(output.bulk).swapExactSyForToken(..." */ add(_105, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 4), and(expr_39, _96))
                            mstore(add(/** @src 19:2403:2562  "IPBulkSeller(output.bulk).swapExactSyForToken(..." */ _105, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 36), param_22)
                            mstore(add(/** @src 19:2403:2562  "IPBulkSeller(output.bulk).swapExactSyForToken(..." */ _105, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 68), 0)
                            mstore(add(/** @src 19:2403:2562  "IPBulkSeller(output.bulk).swapExactSyForToken(..." */ _105, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 100), /** @src 18:1697:1701  "true" */ 0x01)
                            /// @src 19:2403:2562  "IPBulkSeller(output.bulk).swapExactSyForToken(..."
                            let _106 := call(gas(), _104, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0, /** @src 19:2403:2562  "IPBulkSeller(output.bulk).swapExactSyForToken(..." */ _105, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 132, /** @src 19:2403:2562  "IPBulkSeller(output.bulk).swapExactSyForToken(..." */ _105, 32)
                            if iszero(_106)
                            {
                                /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                                let pos_18 := mload(64)
                                returndatacopy(pos_18, 0, returndatasize())
                                revert(pos_18, returndatasize())
                            }
                            /// @src 19:2403:2562  "IPBulkSeller(output.bulk).swapExactSyForToken(..."
                            let expr_42 := /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0
                            /// @src 19:2403:2562  "IPBulkSeller(output.bulk).swapExactSyForToken(..."
                            if _106
                            {
                                let _107 := 32
                                if gt(_107, returndatasize()) { _107 := returndatasize() }
                                finalize_allocation(_105, _107)
                                /// @src 6:315:325  "address(0)"
                                if slt(sub(/** @src 19:2403:2562  "IPBulkSeller(output.bulk).swapExactSyForToken(..." */ add(_105, _107), /** @src 6:315:325  "address(0)" */ _105), /** @src 19:2403:2562  "IPBulkSeller(output.bulk).swapExactSyForToken(..." */ 32)
                                /// @src 6:315:325  "address(0)"
                                {
                                    /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                                    revert(0, 0)
                                }
                                /// @src 19:2403:2562  "IPBulkSeller(output.bulk).swapExactSyForToken(..."
                                expr_42 := /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(_105)
                            }
                            /// @src 19:2384:2562  "netTokenRedeemed = IPBulkSeller(output.bulk).swapExactSyForToken(..."
                            var_netTokenRedeemed_1 := expr_42
                        }
                        /// @src 19:2814:3208  "if (requireSwap) {..."
                        switch expr_38
                        case 0 {
                            /// @src 19:3167:3197  "netTokenOut = netTokenRedeemed"
                            var_netTokenOut_1 := var_netTokenRedeemed_1
                        }
                        default /// @src 19:2814:3208  "if (requireSwap) {..."
                        {
                            /// @src 19:2873:2893  "output.tokenRedeemSy"
                            let expr_43 := read_from_calldatat_address(_99)
                            /// @src 19:2945:2963  "output.kyberRouter"
                            let expr_44 := read_from_calldatat_address(add(param_23, 128))
                            /// @src 19:2981:2997  "output.kybercall"
                            let expr_offset_3, expr_length_3 := access_calldata_tail_bytes_calldata(param_23, add(param_23, 160))
                            fun_kyberswap(expr_43, var_netTokenRedeemed_1, expr_44, expr_offset_3, expr_length_3)
                            /// @src 19:3026:3069  "netTokenOut = _selfBalance(output.tokenOut)"
                            var_netTokenOut_1 := /** @src 19:3040:3069  "_selfBalance(output.tokenOut)" */ fun_selfBalance(/** @src 19:3053:3068  "output.tokenOut" */ read_from_calldatat_address(param_23))
                            /// @src 19:3124:3135  "netTokenOut"
                            fun_transferOut(/** @src 19:3097:3112  "output.tokenOut" */ read_from_calldatat_address(param_23), /** @src 19:3124:3135  "netTokenOut" */ param_20, var_netTokenOut_1)
                        }
                        /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                        let value_3 := calldataload(/** @src 19:3236:3254  "output.minTokenOut" */ add(param_23, 32))
                        /// @src 19:3218:3354  "if (netTokenOut < output.minTokenOut) {..."
                        if /** @src 19:3222:3254  "netTokenOut < output.minTokenOut" */ lt(var_netTokenOut_1, value_3)
                        /// @src 19:3218:3354  "if (netTokenOut < output.minTokenOut) {..."
                        {
                            /// @src 19:3277:3343  "Errors.RouterInsufficientTokenOut(netTokenOut, output.minTokenOut)"
                            let _108 := /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(64)
                            /// @src 19:3277:3343  "Errors.RouterInsufficientTokenOut(netTokenOut, output.minTokenOut)"
                            mstore(_108, shl(224, 0xc5b5576d))
                            /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                            mstore(/** @src 19:3277:3343  "Errors.RouterInsufficientTokenOut(netTokenOut, output.minTokenOut)" */ add(_108, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 4), var_netTokenOut_1)
                            mstore(add(/** @src 19:3277:3343  "Errors.RouterInsufficientTokenOut(netTokenOut, output.minTokenOut)" */ _108, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 36), value_3)
                            /// @src 19:3277:3343  "Errors.RouterInsufficientTokenOut(netTokenOut, output.minTokenOut)"
                            revert(_108, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 68)
                        }
                        let _109 := and(/** @src 18:1745:1760  "output.tokenOut" */ read_from_calldatat_address(param_23), /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _96)
                        /// @src 18:1717:1797  "RedeemSyToToken(msg.sender, output.tokenOut, SY, receiver, netSyIn, netTokenOut)"
                        let _110 := /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(64)
                        /// @src 18:1717:1797  "RedeemSyToToken(msg.sender, output.tokenOut, SY, receiver, netSyIn, netTokenOut)"
                        log4(_110, sub(abi_encode_address_uint256_uint256(_110, param_20, param_22, var_netTokenOut_1), _110), 0xcd34b6ac7e4b72ab30845649aef2f4fd41945ae2dc08f625be69738bbd0f9aa9, /** @src 19:2097:2107  "msg.sender" */ caller(), /** @src 18:1717:1797  "RedeemSyToToken(msg.sender, output.tokenOut, SY, receiver, netSyIn, netTokenOut)" */ _109, _97)
                        /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                        let memPos_5 := mload(64)
                        mstore(memPos_5, var_netTokenOut_1)
                        return(memPos_5, /** @src 19:3236:3254  "output.minTokenOut" */ 32)
                    }
                    case /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0xf7e375e8 {
                        if callvalue() { revert(0, 0) }
                        if slt(add(calldatasize(), not(3)), 128) { revert(0, 0) }
                        let value_4 := calldataload(4)
                        if iszero(eq(value_4, and(value_4, sub(shl(160, 1), 1)))) { revert(0, 0) }
                        let offset := calldataload(36)
                        if gt(offset, 0xffffffffffffffff) { revert(0, 0) }
                        let value1, value2 := abi_decode_array_address_dyn_calldata(add(4, offset), calldatasize())
                        let offset_1 := calldataload(68)
                        if gt(offset_1, 0xffffffffffffffff) { revert(0, 0) }
                        let value3, value4 := abi_decode_array_address_dyn_calldata(add(4, offset_1), calldatasize())
                        let offset_2 := calldataload(100)
                        if gt(offset_2, 0xffffffffffffffff) { revert(0, 0) }
                        let value5, value6 := abi_decode_array_address_dyn_calldata(add(4, offset_2), calldatasize())
                        /// @src 18:4635:4648  "uint256 i = 0"
                        let var_i := /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0
                        /// @src 18:4630:4749  "for (uint256 i = 0; i < sys.length; ++i) {..."
                        for { }
                        /** @src 18:4650:4664  "i < sys.length" */ lt(var_i, /** @src 18:4654:4664  "sys.length" */ value2)
                        /// @src 18:4635:4648  "uint256 i = 0"
                        {
                            /// @src 18:4666:4669  "++i"
                            var_i := /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ add(/** @src 18:4666:4669  "++i" */ var_i, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 1)
                        }
                        /// @src 18:4666:4669  "++i"
                        {
                            /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                            let _111 := and(/** @src 18:4708:4714  "sys[i]" */ read_from_calldatat_address(calldata_array_index_access_address_dyn_calldata(value1, value2, var_i)), /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ sub(shl(160, 1), 1))
                            /// @src 18:4689:4734  "IStandardizedYield(sys[i]).claimRewards(user)"
                            let _112 := /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(64)
                            /// @src 18:4689:4734  "IStandardizedYield(sys[i]).claimRewards(user)"
                            mstore(_112, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ shl(226, 0x3bd73ee3))
                            mstore(/** @src 18:4689:4734  "IStandardizedYield(sys[i]).claimRewards(user)" */ add(_112, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 4), and(value_4, sub(shl(160, 1), 1)))
                            /// @src 18:4689:4734  "IStandardizedYield(sys[i]).claimRewards(user)"
                            let _113 := call(gas(), _111, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0, /** @src 18:4689:4734  "IStandardizedYield(sys[i]).claimRewards(user)" */ _112, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 36, /** @src 18:4689:4734  "IStandardizedYield(sys[i]).claimRewards(user)" */ _112, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0)
                            /// @src 18:4689:4734  "IStandardizedYield(sys[i]).claimRewards(user)"
                            if iszero(_113)
                            {
                                /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                                let pos_19 := mload(64)
                                returndatacopy(pos_19, 0, returndatasize())
                                revert(pos_19, returndatasize())
                            }
                            /// @src 18:4689:4734  "IStandardizedYield(sys[i]).claimRewards(user)"
                            if _113
                            {
                                let _114 := returndatasize()
                                returndatacopy(_112, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0, /** @src 18:4689:4734  "IStandardizedYield(sys[i]).claimRewards(user)" */ _114)
                                finalize_allocation(_112, _114)
                                pop(abi_decode_array_uint256_dyn_fromMemory(_112, add(_112, _114)))
                            }
                        }
                        /// @src 18:4768:4781  "uint256 i = 0"
                        let var_i_1 := /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0
                        /// @src 18:4763:4981  "for (uint256 i = 0; i < yts.length; ++i) {..."
                        for { }
                        /** @src 18:4783:4797  "i < yts.length" */ lt(var_i_1, /** @src 18:4787:4797  "yts.length" */ value4)
                        /// @src 18:4768:4781  "uint256 i = 0"
                        {
                            /// @src 18:4799:4802  "++i"
                            var_i_1 := /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ add(/** @src 18:4799:4802  "++i" */ var_i_1, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 1)
                        }
                        /// @src 18:4799:4802  "++i"
                        {
                            /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                            let _115 := and(/** @src 18:4835:4841  "yts[i]" */ read_from_calldatat_address(calldata_array_index_access_address_dyn_calldata(value3, value4, var_i_1)), /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ sub(shl(160, 1), 1))
                            /// @src 18:4822:4966  "IPYieldToken(yts[i]).redeemDueInterestAndRewards(..."
                            let _116 := /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(64)
                            /// @src 18:4822:4966  "IPYieldToken(yts[i]).redeemDueInterestAndRewards(..."
                            mstore(_116, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ shl(224, 0x7d24da4d))
                            mstore(/** @src 18:4822:4966  "IPYieldToken(yts[i]).redeemDueInterestAndRewards(..." */ add(_116, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 4), and(value_4, sub(shl(160, 1), 1)))
                            let _117 := 1
                            mstore(add(/** @src 18:4822:4966  "IPYieldToken(yts[i]).redeemDueInterestAndRewards(..." */ _116, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 36), _117)
                            mstore(add(/** @src 18:4822:4966  "IPYieldToken(yts[i]).redeemDueInterestAndRewards(..." */ _116, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 68), _117)
                            /// @src 18:4822:4966  "IPYieldToken(yts[i]).redeemDueInterestAndRewards(..."
                            let _118 := call(gas(), _115, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0, /** @src 18:4822:4966  "IPYieldToken(yts[i]).redeemDueInterestAndRewards(..." */ _116, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 100, /** @src 18:4822:4966  "IPYieldToken(yts[i]).redeemDueInterestAndRewards(..." */ _116, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0)
                            /// @src 18:4822:4966  "IPYieldToken(yts[i]).redeemDueInterestAndRewards(..."
                            if iszero(_118)
                            {
                                /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                                let pos_20 := mload(64)
                                returndatacopy(pos_20, 0, returndatasize())
                                revert(pos_20, returndatasize())
                            }
                            /// @src 18:4822:4966  "IPYieldToken(yts[i]).redeemDueInterestAndRewards(..."
                            if _118
                            {
                                let _119 := returndatasize()
                                returndatacopy(_116, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0, /** @src 18:4822:4966  "IPYieldToken(yts[i]).redeemDueInterestAndRewards(..." */ _119)
                                finalize_allocation(_116, _119)
                                let _120 := add(_116, _119)
                                /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                                if slt(sub(_120, _116), 64) { revert(0, 0) }
                                let offset_3 := mload(add(_116, 32))
                                if gt(offset_3, 0xffffffffffffffff) { revert(0, 0) }
                                pop(abi_decode_array_uint256_dyn_memory_ptr_fromMemory(add(_116, offset_3), _120))
                            }
                        }
                        /// @src 18:5000:5013  "uint256 i = 0"
                        let var_i_2 := /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0
                        /// @src 18:4995:5113  "for (uint256 i = 0; i < markets.length; ++i) {..."
                        for { }
                        /** @src 18:5015:5033  "i < markets.length" */ lt(var_i_2, /** @src 18:5019:5033  "markets.length" */ value6)
                        /// @src 18:5000:5013  "uint256 i = 0"
                        {
                            /// @src 18:5035:5038  "++i"
                            var_i_2 := /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ add(/** @src 18:5035:5038  "++i" */ var_i_2, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 1)
                        }
                        /// @src 18:5035:5038  "++i"
                        {
                            /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                            let _121 := and(/** @src 18:5067:5077  "markets[i]" */ read_from_calldatat_address(calldata_array_index_access_address_dyn_calldata(value5, value6, var_i_2)), /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ sub(shl(160, 1), 1))
                            /// @src 18:5058:5098  "IPMarket(markets[i]).redeemRewards(user)"
                            let _122 := /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(64)
                            /// @src 18:5058:5098  "IPMarket(markets[i]).redeemRewards(user)"
                            mstore(_122, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ shl(224, 0x9262187b))
                            mstore(/** @src 18:5058:5098  "IPMarket(markets[i]).redeemRewards(user)" */ add(_122, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 4), and(value_4, sub(shl(160, 1), 1)))
                            /// @src 18:5058:5098  "IPMarket(markets[i]).redeemRewards(user)"
                            let _123 := call(gas(), _121, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0, /** @src 18:5058:5098  "IPMarket(markets[i]).redeemRewards(user)" */ _122, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 36, /** @src 18:5058:5098  "IPMarket(markets[i]).redeemRewards(user)" */ _122, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0)
                            /// @src 18:5058:5098  "IPMarket(markets[i]).redeemRewards(user)"
                            if iszero(_123)
                            {
                                /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                                let pos_21 := mload(64)
                                returndatacopy(pos_21, 0, returndatasize())
                                revert(pos_21, returndatasize())
                            }
                            /// @src 18:5058:5098  "IPMarket(markets[i]).redeemRewards(user)"
                            if _123
                            {
                                let _124 := returndatasize()
                                returndatacopy(_122, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0, /** @src 18:5058:5098  "IPMarket(markets[i]).redeemRewards(user)" */ _124)
                                finalize_allocation(_122, _124)
                                pop(abi_decode_array_uint256_dyn_fromMemory(_122, add(_122, _124)))
                            }
                        }
                        /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                        return(0, 0)
                    }
                    case 0xf9530800 {
                        if callvalue() { revert(0, 0) }
                        if slt(add(calldatasize(), not(3)), 0) { revert(0, 0) }
                        let memPos_6 := mload(64)
                        mstore(memPos_6, and(/** @src 22:1836:1876  "address public immutable kyberScalingLib" */ loadimmutable("8471"), /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ sub(shl(160, 1), 1)))
                        return(memPos_6, 32)
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
                /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                value0 := value
                let value_1 := calldataload(36)
                if iszero(eq(value_1, and(value_1, _1)))
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
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
                /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                value0 := value
                let value_1 := calldataload(36)
                if iszero(eq(value_1, and(value_1, _2)))
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                value1 := value_1
                value2 := calldataload(68)
                let offset := calldataload(100)
                if gt(offset, 0xffffffffffffffff)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                if slt(add(sub(dataEnd, offset), _1), 192)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
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
                /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
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
                    mstore(/** @src -1:-1:-1 */ 0, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ shl(224, 0x4e487b71))
                    mstore(4, 0x41)
                    revert(/** @src -1:-1:-1 */ 0, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0x24)
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
                /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
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
            function access_calldata_tail_bytes_calldata(base_ref, ptr_to_tail) -> addr, length
            {
                let rel_offset_of_tail := calldataload(ptr_to_tail)
                if iszero(slt(rel_offset_of_tail, add(sub(calldatasize(), base_ref), not(30)))) { revert(0, 0) }
                let addr_1 := add(base_ref, rel_offset_of_tail)
                length := calldataload(addr_1)
                if gt(length, 0xffffffffffffffff) { revert(0, 0) }
                addr := add(addr_1, 0x20)
                if sgt(addr, sub(calldatasize(), length)) { revert(0, 0) }
            }
            /// @ast-id 2810 @src 6:1721:1896  "function _selfBalance(address token) internal view returns (uint256) {..."
            function fun_selfBalance(var_token) -> var
            {
                /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                let _1 := and(/** @src 6:1808:1823  "token == NATIVE" */ var_token, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ sub(shl(160, 1), 1))
                /// @src 6:1807:1889  "(token == NATIVE) ? address(this).balance : IERC20(token).balanceOf(address(this))"
                let expr := /** @src 6:323:324  "0" */ 0x00
                /// @src 6:1807:1889  "(token == NATIVE) ? address(this).balance : IERC20(token).balanceOf(address(this))"
                switch /** @src 6:1808:1823  "token == NATIVE" */ iszero(/** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _1)
                case /** @src 6:1807:1889  "(token == NATIVE) ? address(this).balance : IERC20(token).balanceOf(address(this))" */ 0 {
                    /// @src 6:1851:1889  "IERC20(token).balanceOf(address(this))"
                    let _2 := /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(64)
                    /// @src 6:1851:1889  "IERC20(token).balanceOf(address(this))"
                    mstore(_2, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ shl(224, 0x70a08231))
                    mstore(/** @src 6:1851:1889  "IERC20(token).balanceOf(address(this))" */ add(_2, 4), /** @src 6:1883:1887  "this" */ address())
                    /// @src 6:1851:1889  "IERC20(token).balanceOf(address(this))"
                    let _3 := staticcall(gas(), _1, _2, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 36, /** @src 6:1851:1889  "IERC20(token).balanceOf(address(this))" */ _2, 32)
                    if iszero(_3)
                    {
                        /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                        let pos := mload(64)
                        returndatacopy(pos, /** @src 6:323:324  "0" */ expr, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ returndatasize())
                        revert(pos, returndatasize())
                    }
                    /// @src 6:1851:1889  "IERC20(token).balanceOf(address(this))"
                    let expr_1 := /** @src 6:323:324  "0" */ expr
                    /// @src 6:1851:1889  "IERC20(token).balanceOf(address(this))"
                    if _3
                    {
                        let _4 := 32
                        if gt(_4, returndatasize()) { _4 := returndatasize() }
                        finalize_allocation(_2, _4)
                        /// @src 6:315:325  "address(0)"
                        if slt(sub(/** @src 6:1851:1889  "IERC20(token).balanceOf(address(this))" */ add(_2, _4), /** @src 6:315:325  "address(0)" */ _2), /** @src 6:1851:1889  "IERC20(token).balanceOf(address(this))" */ 32)
                        /// @src 6:315:325  "address(0)"
                        {
                            /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                            revert(/** @src 6:323:324  "0" */ expr, expr)
                        }
                        /// @src 6:1851:1889  "IERC20(token).balanceOf(address(this))"
                        expr_1 := /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(_2)
                    }
                    /// @src 6:1807:1889  "(token == NATIVE) ? address(this).balance : IERC20(token).balanceOf(address(this))"
                    expr := expr_1
                }
                default {
                    expr := /** @src 6:1827:1848  "address(this).balance" */ selfbalance()
                }
                /// @src 6:1800:1889  "return (token == NATIVE) ? address(this).balance : IERC20(token).balanceOf(address(this))"
                var := expr
            }
            /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
            function array_allocation_size_bytes(length) -> size
            {
                if gt(length, 0xffffffffffffffff)
                {
                    mstore(0, shl(224, 0x4e487b71))
                    mstore(4, 0x41)
                    revert(0, 0x24)
                }
                size := add(and(add(length, 31), not(31)), 0x20)
            }
            function extract_returndata() -> data
            {
                switch returndatasize()
                case 0 { data := 96 }
                default {
                    let _1 := returndatasize()
                    let _2 := array_allocation_size_bytes(_1)
                    let memPtr := mload(64)
                    finalize_allocation(memPtr, _2)
                    mstore(memPtr, _1)
                    data := memPtr
                    returndatacopy(add(memPtr, 0x20), /** @src -1:-1:-1 */ 0, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ returndatasize())
                }
            }
            /// @ast-id 2734 @src 6:937:1301  "function _transferOut(..."
            function fun_transferOut(var_token, var_to, var_amount)
            {
                /// @src 6:1051:1075  "if (amount == 0) return;"
                if /** @src 6:1055:1066  "amount == 0" */ iszero(var_amount)
                /// @src 6:1051:1075  "if (amount == 0) return;"
                {
                    /// @src 6:1068:1075  "return;"
                    leave
                }
                /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                let _1 := sub(shl(160, 1), 1)
                let _2 := and(/** @src 6:1088:1103  "token == NATIVE" */ var_token, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _1)
                /// @src 6:1084:1295  "if (token == NATIVE) {..."
                switch /** @src 6:1088:1103  "token == NATIVE" */ iszero(/** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _2)
                case /** @src 6:1084:1295  "if (token == NATIVE) {..." */ 0 {
                    /// @src 26:902:960  "abi.encodeWithSelector(token.transfer.selector, to, value)"
                    let expr_mpos := /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(64)
                    /// @src 26:902:960  "abi.encodeWithSelector(token.transfer.selector, to, value)"
                    mstore(add(expr_mpos, 0x20), /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ shl(224, 0xa9059cbb))
                    mstore(/** @src 26:902:960  "abi.encodeWithSelector(token.transfer.selector, to, value)" */ add(expr_mpos, 36), /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ and(var_to, _1))
                    mstore(add(/** @src 26:902:960  "abi.encodeWithSelector(token.transfer.selector, to, value)" */ expr_mpos, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 68), var_amount)
                    /// @src 26:902:960  "abi.encodeWithSelector(token.transfer.selector, to, value)"
                    mstore(expr_mpos, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 68)
                    let newFreePtr := add(expr_mpos, 128)
                    if or(gt(newFreePtr, 0xffffffffffffffff), lt(newFreePtr, expr_mpos))
                    {
                        mstore(0, shl(224, 0x4e487b71))
                        mstore(4, 0x41)
                        revert(0, /** @src 26:902:960  "abi.encodeWithSelector(token.transfer.selector, to, value)" */ 36)
                    }
                    /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                    mstore(64, newFreePtr)
                    /// @src 26:902:960  "abi.encodeWithSelector(token.transfer.selector, to, value)"
                    fun_callOptionalReturn(_2, expr_mpos)
                }
                default /// @src 6:1084:1295  "if (token == NATIVE) {..."
                {
                    /// @src 6:1138:1166  "to.call{ value: amount }(\"\")"
                    let expr_component := call(gas(), var_to, var_amount, /** @src 6:1065:1066  "0" */ 0x00, 0x00, 0x00, 0x00)
                    /// @src 6:1138:1166  "to.call{ value: amount }(\"\")"
                    pop(extract_returndata())
                    /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                    if iszero(expr_component)
                    {
                        let memPtr := mload(64)
                        mstore(memPtr, shl(229, 4594637))
                        mstore(add(memPtr, 4), 32)
                        mstore(add(memPtr, 36), 15)
                        mstore(add(memPtr, 68), "eth send failed")
                        revert(memPtr, 100)
                    }
                }
            }
            function abi_decode_bool_fromMemory(headStart, dataEnd) -> value0
            {
                if slt(sub(dataEnd, headStart), 32) { revert(0, 0) }
                let value := mload(headStart)
                if iszero(eq(value, iszero(iszero(value))))
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                value0 := value
            }
            /// @ast-id 6456 @src 19:4404:4597  "function _syOrBulk(address SY, TokenOutput calldata output)..."
            function fun_syOrBulk(var_SY, var_output_offset) -> var_addr
            {
                /// @src 19:4546:4557  "output.bulk"
                let _1 := add(var_output_offset, 96)
                /// @src 19:4546:4571  "output.bulk != address(0)"
                let expr := iszero(iszero(/** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ and(/** @src 19:4546:4557  "output.bulk" */ read_from_calldatat_address(_1), /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ sub(shl(160, 1), 1))))
                /// @src 19:4546:4590  "output.bulk != address(0) ? output.bulk : SY"
                let expr_1 := /** @src 19:4569:4570  "0" */ 0x00
                /// @src 19:4546:4590  "output.bulk != address(0) ? output.bulk : SY"
                switch expr
                case 0 { expr_1 := var_SY }
                default {
                    expr_1 := /** @src 19:4574:4585  "output.bulk" */ read_from_calldatat_address(_1)
                }
                /// @src 19:4539:4590  "return output.bulk != address(0) ? output.bulk : SY"
                var_addr := expr_1
            }
            /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
            function copy_memory_to_memory_with_cleanup(src, dst, length)
            {
                let i := 0
                for { } lt(i, length) { i := add(i, 32) }
                {
                    mstore(add(dst, i), mload(add(src, i)))
                }
                mstore(add(dst, length), 0)
            }
            /// @ast-id 8528 @src 22:1978:2455  "function _kyberswap(..."
            function fun_kyberswap(var_tokenIn, var_amountIn, var_kyberRouter, var_rawKybercall_offset, var_rawKybercall_length)
            {
                /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                let _1 := sub(shl(160, 1), 1)
                /// @src 22:2144:2197  "kyberRouter == address(0) || rawKybercall.length == 0"
                let expr := /** @src 22:2144:2169  "kyberRouter == address(0)" */ iszero(/** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ and(/** @src 22:2144:2169  "kyberRouter == address(0)" */ var_kyberRouter, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _1))
                /// @src 22:2144:2197  "kyberRouter == address(0) || rawKybercall.length == 0"
                if iszero(expr)
                {
                    expr := /** @src 22:2173:2197  "rawKybercall.length == 0" */ iszero(var_rawKybercall_length)
                }
                /// @src 22:2140:2250  "if (kyberRouter == address(0) || rawKybercall.length == 0)..."
                if expr
                {
                    /// @src 22:2218:2250  "Errors.RouterKyberSwapDataZero()"
                    let _2 := /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(64)
                    /// @src 22:2218:2250  "Errors.RouterKyberSwapDataZero()"
                    mstore(_2, shl(224, 0x1e59c843))
                    revert(_2, 4)
                }
                /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                let _3 := 64
                /// @src 22:2308:2392  "IAggregationRouterHelper(kyberScalingLib).getScaledInputData(rawKybercall, amountIn)"
                let _4 := /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(_3)
                /// @src 22:2308:2392  "IAggregationRouterHelper(kyberScalingLib).getScaledInputData(rawKybercall, amountIn)"
                mstore(_4, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ shl(225, 0x726d3797))
                mstore(/** @src 22:2308:2392  "IAggregationRouterHelper(kyberScalingLib).getScaledInputData(rawKybercall, amountIn)" */ add(_4, 4), /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _3)
                mstore(add(/** @src 22:2308:2392  "IAggregationRouterHelper(kyberScalingLib).getScaledInputData(rawKybercall, amountIn)" */ _4, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 68), var_rawKybercall_length)
                calldatacopy(add(/** @src 22:2308:2392  "IAggregationRouterHelper(kyberScalingLib).getScaledInputData(rawKybercall, amountIn)" */ _4, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 100), var_rawKybercall_offset, var_rawKybercall_length)
                /// @src 22:2167:2168  "0"
                let _5 := 0x00
                /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                mstore(add(add(/** @src 22:2308:2392  "IAggregationRouterHelper(kyberScalingLib).getScaledInputData(rawKybercall, amountIn)" */ _4, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ var_rawKybercall_length), 100), /** @src 22:2167:2168  "0" */ _5)
                /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                mstore(add(/** @src 22:2308:2392  "IAggregationRouterHelper(kyberScalingLib).getScaledInputData(rawKybercall, amountIn)" */ _4, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 36), var_amountIn)
                /// @src 22:2308:2392  "IAggregationRouterHelper(kyberScalingLib).getScaledInputData(rawKybercall, amountIn)"
                let _6 := staticcall(gas(), /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ and(/** @src 22:2333:2348  "kyberScalingLib" */ loadimmutable("8471"), /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _1), /** @src 22:2308:2392  "IAggregationRouterHelper(kyberScalingLib).getScaledInputData(rawKybercall, amountIn)" */ _4, add(sub(/** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ add(/** @src 22:2308:2392  "IAggregationRouterHelper(kyberScalingLib).getScaledInputData(rawKybercall, amountIn)" */ _4, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ and(add(var_rawKybercall_length, 31), not(31))), /** @src 22:2308:2392  "IAggregationRouterHelper(kyberScalingLib).getScaledInputData(rawKybercall, amountIn)" */ _4), /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 100), /** @src 22:2308:2392  "IAggregationRouterHelper(kyberScalingLib).getScaledInputData(rawKybercall, amountIn)" */ _4, /** @src 22:2167:2168  "0" */ _5)
                /// @src 22:2308:2392  "IAggregationRouterHelper(kyberScalingLib).getScaledInputData(rawKybercall, amountIn)"
                if iszero(_6)
                {
                    /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                    let pos := mload(_3)
                    returndatacopy(pos, /** @src 22:2167:2168  "0" */ _5, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ returndatasize())
                    revert(pos, returndatasize())
                }
                /// @src 22:2308:2392  "IAggregationRouterHelper(kyberScalingLib).getScaledInputData(rawKybercall, amountIn)"
                let expr_8518_mpos := /** @src 22:2167:2168  "0" */ _5
                /// @src 22:2308:2392  "IAggregationRouterHelper(kyberScalingLib).getScaledInputData(rawKybercall, amountIn)"
                if _6
                {
                    let _7 := returndatasize()
                    returndatacopy(_4, /** @src 22:2167:2168  "0" */ _5, /** @src 22:2308:2392  "IAggregationRouterHelper(kyberScalingLib).getScaledInputData(rawKybercall, amountIn)" */ _7)
                    finalize_allocation(_4, _7)
                    let _8 := add(_4, _7)
                    /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                    if slt(sub(_8, _4), 0x20)
                    {
                        revert(/** @src 22:2167:2168  "0" */ _5, _5)
                    }
                    /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                    let offset := mload(_4)
                    if gt(offset, 0xffffffffffffffff)
                    {
                        revert(/** @src 22:2167:2168  "0" */ _5, _5)
                    }
                    /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                    let _9 := add(_4, offset)
                    if iszero(slt(add(_9, 31), _8))
                    {
                        revert(/** @src 22:2167:2168  "0" */ _5, _5)
                    }
                    /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                    let _10 := mload(_9)
                    let _11 := array_allocation_size_bytes(_10)
                    let memPtr := mload(_3)
                    finalize_allocation(memPtr, _11)
                    mstore(memPtr, _10)
                    if gt(add(add(_9, _10), 0x20), _8)
                    {
                        revert(/** @src 22:2167:2168  "0" */ _5, _5)
                    }
                    /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                    copy_memory_to_memory_with_cleanup(add(_9, 0x20), add(memPtr, 0x20), _10)
                    /// @src 22:2308:2392  "IAggregationRouterHelper(kyberScalingLib).getScaledInputData(rawKybercall, amountIn)"
                    expr_8518_mpos := memPtr
                }
                /// @src 22:2406:2438  "tokenIn == NATIVE ? amountIn : 0"
                let expr_1 := /** @src 22:2167:2168  "0" */ _5
                /// @src 22:2406:2438  "tokenIn == NATIVE ? amountIn : 0"
                switch /** @src 22:2406:2423  "tokenIn == NATIVE" */ iszero(/** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ and(/** @src 22:2406:2423  "tokenIn == NATIVE" */ var_tokenIn, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _1))
                case /** @src 22:2406:2438  "tokenIn == NATIVE ? amountIn : 0" */ 0 {
                    expr_1 := /** @src 22:2167:2168  "0" */ _5
                }
                default /// @src 22:2406:2438  "tokenIn == NATIVE ? amountIn : 0"
                { expr_1 := var_amountIn }
                /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                let memPtr_1 := mload(_3)
                let newFreePtr := add(memPtr_1, 96)
                if or(gt(newFreePtr, 0xffffffffffffffff), lt(newFreePtr, memPtr_1))
                {
                    mstore(/** @src 22:2167:2168  "0" */ _5, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ shl(224, 0x4e487b71))
                    mstore(/** @src 22:2308:2392  "IAggregationRouterHelper(kyberScalingLib).getScaledInputData(rawKybercall, amountIn)" */ 4, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0x41)
                    revert(/** @src 22:2167:2168  "0" */ _5, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 36)
                }
                mstore(_3, newFreePtr)
                mstore(memPtr_1, 41)
                mstore(add(memPtr_1, 0x20), "Address: low-level call with val")
                mstore(add(memPtr_1, _3), "ue failed")
                if /** @src 27:5145:5175  "address(this).balance >= value" */ lt(/** @src 27:5145:5166  "address(this).balance" */ selfbalance(), /** @src 27:5145:5175  "address(this).balance >= value" */ expr_1)
                /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                {
                    let memPtr_2 := mload(_3)
                    mstore(memPtr_2, shl(229, 4594637))
                    mstore(add(memPtr_2, /** @src 22:2308:2392  "IAggregationRouterHelper(kyberScalingLib).getScaledInputData(rawKybercall, amountIn)" */ 4), /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0x20)
                    mstore(add(memPtr_2, 36), 38)
                    mstore(add(memPtr_2, 68), "Address: insufficient balance fo")
                    mstore(add(memPtr_2, 100), "r call")
                    revert(memPtr_2, 132)
                }
                if /** @src 27:1465:1488  "account.code.length > 0" */ iszero(/** @src 27:1465:1484  "account.code.length" */ extcodesize(var_kyberRouter))
                /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                {
                    let memPtr_3 := mload(_3)
                    mstore(memPtr_3, shl(229, 4594637))
                    mstore(add(memPtr_3, /** @src 22:2308:2392  "IAggregationRouterHelper(kyberScalingLib).getScaledInputData(rawKybercall, amountIn)" */ 4), /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0x20)
                    mstore(add(memPtr_3, 36), 29)
                    mstore(add(memPtr_3, 68), "Address: call to non-contract")
                    revert(memPtr_3, 100)
                }
                /// @src 27:5341:5372  "target.call{value: value}(data)"
                let expr_component := call(gas(), var_kyberRouter, expr_1, add(expr_8518_mpos, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 0x20), /** @src 27:5341:5372  "target.call{value: value}(data)" */ mload(expr_8518_mpos), /** @src 22:2167:2168  "0" */ _5, _5)
                /// @src 27:5389:5440  "verifyCallResult(success, returndata, errorMessage)"
                pop(fun_verifyCallResult(expr_component, /** @src 27:5341:5372  "target.call{value: value}(data)" */ extract_returndata(), /** @src 27:5389:5440  "verifyCallResult(success, returndata, errorMessage)" */ memPtr_1))
            }
            /// @ast-id 8726 @src 26:974:1215  "function safeTransferFrom(..."
            function fun_safeTransferFrom(var_token_address, var_from, var_to, var_value)
            {
                /// @src 26:1139:1207  "abi.encodeWithSelector(token.transferFrom.selector, from, to, value)"
                let expr_8722_mpos := /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(64)
                /// @src 26:1139:1207  "abi.encodeWithSelector(token.transferFrom.selector, from, to, value)"
                mstore(add(expr_8722_mpos, 0x20), /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ shl(224, 0x23b872dd))
                let _1 := sub(shl(160, 1), 1)
                mstore(/** @src 26:1139:1207  "abi.encodeWithSelector(token.transferFrom.selector, from, to, value)" */ add(expr_8722_mpos, 36), /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ and(var_from, _1))
                mstore(add(/** @src 26:1139:1207  "abi.encodeWithSelector(token.transferFrom.selector, from, to, value)" */ expr_8722_mpos, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 68), and(var_to, _1))
                mstore(add(/** @src 26:1139:1207  "abi.encodeWithSelector(token.transferFrom.selector, from, to, value)" */ expr_8722_mpos, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 100), var_value)
                /// @src 26:1139:1207  "abi.encodeWithSelector(token.transferFrom.selector, from, to, value)"
                mstore(expr_8722_mpos, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 100)
                let newFreePtr := add(expr_8722_mpos, 160)
                if or(gt(newFreePtr, 0xffffffffffffffff), lt(newFreePtr, expr_8722_mpos))
                {
                    mstore(0, shl(224, 0x4e487b71))
                    mstore(4, 0x41)
                    revert(0, /** @src 26:1139:1207  "abi.encodeWithSelector(token.transferFrom.selector, from, to, value)" */ 36)
                }
                /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                mstore(64, newFreePtr)
                /// @src 26:1139:1207  "abi.encodeWithSelector(token.transferFrom.selector, from, to, value)"
                fun_callOptionalReturn(var_token_address, expr_8722_mpos)
            }
            /// @ast-id 8948 @src 26:3747:4453  "function _callOptionalReturn(IERC20 token, bytes memory data) private {..."
            function fun_callOptionalReturn(var_token_8914_address, var_data_mpos)
            {
                /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                let _1 := and(/** @src 26:4192:4206  "address(token)" */ var_token_8914_address, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ sub(shl(160, 1), 1))
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
                /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                {
                    let memPtr_1 := mload(64)
                    mstore(memPtr_1, shl(229, 4594637))
                    mstore(add(memPtr_1, 4), _2)
                    mstore(add(memPtr_1, 36), 29)
                    mstore(add(memPtr_1, 68), "Address: call to non-contract")
                    revert(memPtr_1, 100)
                }
                /// @src 27:5341:5372  "target.call{value: value}(data)"
                let expr_component := call(gas(), _1, /** @src -1:-1:-1 */ 0, /** @src 27:5341:5372  "target.call{value: value}(data)" */ add(var_data_mpos, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _2), /** @src 27:5341:5372  "target.call{value: value}(data)" */ mload(var_data_mpos), /** @src -1:-1:-1 */ 0, 0)
                /// @src 27:5382:5440  "return verifyCallResult(success, returndata, errorMessage)"
                let var_mpos := /** @src 27:5389:5440  "verifyCallResult(success, returndata, errorMessage)" */ fun_verifyCallResult(expr_component, /** @src 27:5341:5372  "target.call{value: value}(data)" */ extract_returndata(), /** @src 27:5389:5440  "verifyCallResult(success, returndata, errorMessage)" */ memPtr)
                /// @src 26:4275:4292  "returndata.length"
                let expr := /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(/** @src 26:4275:4292  "returndata.length" */ var_mpos)
                /// @src 26:4271:4447  "if (returndata.length > 0) {..."
                if /** @src 26:4275:4296  "returndata.length > 0" */ iszero(iszero(expr))
                /// @src 26:4271:4447  "if (returndata.length > 0) {..."
                {
                    /// @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..."
                    if iszero(/** @src 26:4359:4389  "abi.decode(returndata, (bool))" */ abi_decode_bool_fromMemory(add(var_mpos, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _2), /** @src 26:4359:4389  "abi.decode(returndata, (bool))" */ add(add(var_mpos, expr), /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ _2)))
                    {
                        let memPtr_2 := mload(64)
                        mstore(memPtr_2, shl(229, 4594637))
                        mstore(add(memPtr_2, 4), _2)
                        mstore(add(memPtr_2, 36), 42)
                        mstore(add(memPtr_2, 68), "SafeERC20: ERC20 operation did n")
                        mstore(add(memPtr_2, 100), "ot succeed")
                        revert(memPtr_2, 132)
                    }
                }
            }
            /// @ast-id 9243 @src 27:7561:8303  "function verifyCallResult(..."
            function fun_verifyCallResult(var_success, var_returndata_mpos, var_errorMessage_mpos) -> var_mpos
            {
                /// @src 27:7707:7719  "bytes memory"
                var_mpos := /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 96
                /// @src 27:7731:8297  "if (success) {..."
                switch var_success
                case 0 {
                    /// @src 27:7872:8287  "if (returndata.length > 0) {..."
                    switch /** @src 27:7876:7897  "returndata.length > 0" */ iszero(iszero(/** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(/** @src 27:7876:7893  "returndata.length" */ var_returndata_mpos)))
                    case /** @src 27:7872:8287  "if (returndata.length > 0) {..." */ 0 {
                        /// @src 27:8252:8272  "revert(errorMessage)"
                        let _1 := /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ mload(64)
                        /// @src 27:8252:8272  "revert(errorMessage)"
                        mstore(_1, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ shl(229, 4594637))
                        mstore(/** @src 27:8252:8272  "revert(errorMessage)" */ add(_1, 4), /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 32)
                        let length := mload(var_errorMessage_mpos)
                        mstore(add(/** @src 27:8252:8272  "revert(errorMessage)" */ _1, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 36), length)
                        copy_memory_to_memory_with_cleanup(add(var_errorMessage_mpos, 32), add(/** @src 27:8252:8272  "revert(errorMessage)" */ _1, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 68), length)
                        /// @src 27:8252:8272  "revert(errorMessage)"
                        revert(_1, add(sub(/** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ add(/** @src 27:8252:8272  "revert(errorMessage)" */ _1, /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ and(add(length, 31), not(31))), /** @src 27:8252:8272  "revert(errorMessage)" */ _1), /** @src 18:236:5131  "contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {..." */ 68))
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
        data ".metadata" hex"a264697066735822122010bf930927c9ebd6748e3f42321ccf56bd78f341cb266719abcb3ff8feebed2b64736f6c63430008110033"
    }
}


/**
* @file src/bin2llvmir/optimizations/decoder/mips.cpp
* @brief Decoding methods specific to MIPS architecture.
* @copyright (c) 2017 Avast Software, licensed under the MIT license
*/

#include "retdec/bin2llvmir/optimizations/decoder/decoder.h"
#include "retdec/bin2llvmir/utils/capstone.h"
#include "retdec/utils/string.h"

using namespace retdec::utils;
using namespace retdec::capstone2llvmir;
using namespace llvm;

namespace retdec {
namespace bin2llvmir {

std::size_t Decoder::decodeJumpTargetDryRun_mips(
		const JumpTarget& jt,
		ByteData bytes)
{
	static csh ce = _c2l->getCapstoneEngine();

	uint64_t addr = jt.getAddress();
	std::size_t nops = 0;
	bool first = true;
	unsigned counter = 0;
	unsigned cfChangePos = 0;
	while (cs_disasm_iter(ce, &bytes.first, &bytes.second, &addr, _dryCsInsn))
	{
		++counter;

		if (jt.getType() == JumpTarget::eType::LEFTOVER
				&& (first || nops > 0)
				&& capstone_utils::isNopInstruction(
						_config->getConfig().architecture,
						_dryCsInsn))
		{
			nops += _dryCsInsn->size;
		}
		else if (jt.getType() == JumpTarget::eType::LEFTOVER
				&& nops > 0)
		{
			return nops;
		}

		if (_c2l->isReturnInstruction(*_dryCsInsn)
				|| _c2l->isBranchInstruction(*_dryCsInsn))
		{
			return false;
		}
		else if (_c2l->isBranchInstruction(*_dryCsInsn)
				|| _c2l->isCallInstruction(*_dryCsInsn))
		{
			cfChangePos = counter;
		}

		first = false;
	}

	if (nops > 0)
	{
		return nops;
	}

	// There is a BB right after, that is not a function start.
	//
	if (getBasicBlockAtAddress(addr) && getFunctionAtAddress(addr) == nullptr)
	{
		return false;
	}

	// We decoded exactly tho whole range, there is at least some good number
	// of instructions, and block ended with control flow change (+possible
	// delay slot).
	//
	if (bytes.second == 0
			&& counter >= 8
			&& (cfChangePos == counter || cfChangePos+1 == counter))
	{
		return false;
	}

	return true;
}

} // namespace bin2llvmir
} // namespace retdec
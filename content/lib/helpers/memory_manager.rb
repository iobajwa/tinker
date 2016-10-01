
# class provides abstraction for reading/writing from/to different kinds of memories that a CPU posseses.
# The class automatically takes care of any boundary conditions

class MemoryManager
	attr_accessor :memories
	
	def initialize(memories=[])
		@memories = memories
	end

	def add_memory(memory)
		@memories.push memory if memory != nil && memory.has_valid_permissions
	end

	def write_byte(byte, address, to_memory=nil)
		raise "Not Implemented!"
	end

	def read_byte(address, from_memory=nil)
		raise "Not Implemented!"
		return nil
	end
end

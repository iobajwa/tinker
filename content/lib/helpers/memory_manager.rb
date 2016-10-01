
[
	"memory.rb",
	"tool_messages.rb",
].each {  |req| require "#{File.expand_path(File.dirname(__FILE__))}/#{req}" }

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
		
		byte &= 0xff

		if to_memory == nil
			write_success = false
			@memories.each {  |m|
				next unless m.is_address_within_bounds address
				m.write_byte byte, address
				write_success = true
				break
			}
			raise ToolException.new "MemoryManager.write_byte: address '#{address}' does not exist" unless write_success
		else
			m = get_memory to_memory
			raise ToolException.new "MemoryManager.write_byte: No memory found named as '#{to_memory}'" unless m
			m.write_byte byte, address
		end
	end

	def read_byte(address, from_memory=nil)
		if from_memory == nil
			@memories.each {  |m|
				next unless m.is_address_within_bounds address
				return m.read_byte address
			}
			raise ToolException.new "MemoryManager.read_byte: address '#{address}' does not exist"
		else
			m = get_memory from_memory
			raise ToolException.new "MemoryManager.read_byte: No memory found named as '#{from_memory}'" unless m
			return m.read_byte address
		end
	end

	def get_memory(name)
		@memories.each {  |m| return m if m.name.downcase == name.downcase  }
		return nil
	end

	def address_exists?(address)
	end

	def MemoryManager.parse(raw)
		raise ToolException.new "MemoryManager.parse: raw metadata must be a Hash" if raw == nil || raw.class != Hash

		memories = []
		raw.each_pair {  |k,v|
			memories.push Memory.parse( { k =>v } )
		}

		return MemoryManager.new memories
	end
end


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
		@memories.push memory if memory&.has_valid_permissions
	end

	def [](id)
		begin
			return find_memory id
		rescue ToolException => ex
			raise ToolException.new "MemoryManager['#{id}']: " + ex.message
		end
	end

	def []=(id, value)
		begin
			m = find_memory id
			m.fill_all value
		rescue ToolException => ex
			raise ToolException.new "MemoryManager['#{id}']: " + ex.message
		end
	end

	def count
		return @memories.length
	end

	def each(&func)
		@memories.each {  |m|
			func.call m
		} if func
	end

	# returns a hash of memory-names => memory-sizes
	def list
		names = {}
		@memories.each {  |m| names[m.name] = m.size  }
		return names
	end

	def write_byte(address, byte, to_memory=nil)
		
		byte &= 0xff

		if to_memory == nil
			write_success = false
			@memories.each {  |m|
				next unless m.address_exists? address
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
				next unless m.address_exists? address
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
		@memories.each { |m| return true if m.address_exists? address }
		return false
	end

	def MemoryManager.parse(raw)
		raise ToolException.new "MemoryManager.parse: raw metadata must be a Hash" if raw&.class != Hash

		unsorted_memories = []
		raw.each_pair {  |k,v|
			unsorted_memories.push Memory.parse( { k => v } )
		}

		sorted_memories = MemoryManager.sort_memories unsorted_memories
		MemoryManager.check_if_memories_overlap sorted_memories

		return MemoryManager.new sorted_memories
	end

	def MemoryManager.sort_memories(raw)
		result = {}
		raw.each {  |m| result[m.start_address] = m  }
		return result.sort.to_h.values
	end

	def MemoryManager.check_if_memories_overlap(memories)
		memories.each {  |m|
			memories.each {  |c|
				next if m.name == c.name
				if m.address_exists?( c.start_address )
					raise ToolException.new "MemoryManager: memories overlap: '#{m.name}' (#{m.start_address}, #{m.size}) and '#{c.name}' (#{c.start_address}, #{c.size})"
				end
			}
		}
	end

	private
	def find_memory(id)
		m = nil
		case id.class.to_s
			when "Fixnum" then m = @memories[id]
			when "String" then m = get_memory id
			else raise ToolException.new "only integer or string type as parameter is accepted"
		end
		raise ToolException.new "memory does not exists" unless m
		return m
	end
end

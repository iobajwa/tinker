
[
	"memory_manager",
	"tool_messages",
	"hex_file",
].each {  |req| require "#{File.expand_path(File.dirname(__FILE__))}/#{req}" }

class CPU
	attr_accessor :name,
	              :instruction_size,     # in bits
	              :padding_instruction,  # for cpus which packs it data in flash using an instruction such as 'movlw'
	              :memory_manager

	def initialize(name, instruction_size, padding_instruction=nil, memories={})
		@name                = name
		@instruction_size    = instruction_size
		@padding_instruction = padding_instruction
		@memory_manager      = memories == {} ? MemoryManager.new : MemoryManager.parse( memories )
	end

	def mount_hex(raw_lines)
		HexFile.parse(raw_lines) {  |address, byte|
			@memory_manager.write_byte address, byte
		} if raw_lines
	end

	def write_memory(memory_name, address, data, size)
		raise "Not Implemented!"
	end

	def read_memory(memory_name, address, size)
		raise "Not Implemented!"
	end




	# can parse from following data-structures
	# 'name' :=> string, '<name> (, <aliases>)?'
	# hash = { :name => 'name', :instruction_size => Fixnum, :padding_instruction => Fixnum/string, :memories => {..} }
	def CPU.parse(raw)
		raise ToolException.new "CPU.parse: nothing to parse" if raw == nil

		found_cpu = nil
		if raw.class == String
			found_cpu = CPU.find_cpu_metadata(CPU.parse_names(raw))
		elsif raw.class == Hash
			found_cpu = raw
		else
			raise ToolException.new "CPU.parse: invalid format"
		end

		name                = found_cpu[:name]
		instruction_size    = found_cpu[:instruction_size]
		padding_instruction = found_cpu[:padding_instruction]
		memories            = found_cpu[:memories]
		memories            = {} if memories == nil
		
		raise ToolException.new "CPU.parse: instruction_size for '#{name}' cpu not defined" if instruction_size == nil || instruction_size.class != Fixnum
		raise ToolException.new "CPU.parse: memories for '#{name}' cpu defined in incorrect format" if memories.class != Hash
		raise ToolException.new "CPU.parse: '#{name}' cpu has no memories defined" if memories.length == 0

		return CPU.new name, instruction_size, padding_instruction, memories
	end

	def CPU.known_cpus
		return @@known_cpus
	end


	@@known_cpus = {
		"pic16f1516" => {
			:aliases => [ 'p16f1516' ],
			:metadata => {
				:instruction_size => 14,
				:padding_instruction => 0x34,
				:memories => {
					"flash" => {
						:start_address => 0,
						:size => 0xFFFF
					},
					"config_words" => {
						:start_address => 0x10000,
						:size => 32
					},
				}, # :memories
			}, # :metadata
		}, # pic16f1516
	}


	# helpers
	def CPU.parse_names(raw)
		tnames = raw.split(',').map(&:strip).map(&:to_s).map(&:downcase)
		names = []
		tnames.each {  |n| names.push n unless n == ""  }
		raise ToolException.new "CPU.parse: no cpu name provided" if names.length == 0
		return names
	end

	def CPU.find_cpu_metadata(hints)
		cpus = CPU.known_cpus
		cpu = cpus[hints[0]]
		return cpu[:metadata] unless cpu == nil

		first_name = hints.shift
		cpus.each_pair {  |c, v|
			
			found   = false
			aliases = v[:aliases]
			
			next if aliases == nil

			aliases.each  {  |a|
				found = hints.include?(a)
				break if found
			}

			return v[:metadata] if found
		}

		hints = [first_name, hints ].flatten
		raise ToolException.new "CPU.parse: no matching cpu found from '#{hints}'"
	end
end


[
	"memory_manager",
	"tool_messages",
	"hex_file",
].each {  |req| require "#{File.expand_path(File.dirname(__FILE__))}/#{req}" }

class CPU
	attr_accessor :name,
	              :memories

	def initialize(name, memories={})
		@name           = name
		@memories = memories == {} ? MemoryManager.new : MemoryManager.parse( memories )
	end

	def mount_hex(raw_lines)
		HexFile.parse(raw_lines) {  |address, byte|
			@memories.write_byte address, byte
		} if raw_lines
	end

	def write_object(memory_name, address, data, size)
		# before writing memory, we append the data using
		@memories.write_byte
		raise "Not Implemented!"
	end

	def read_object(memory_name, address, size)
		raise "Not Implemented!"
	end




	# can parse from following data-structures
	# 'name' :=> string, '<name> (, <aliases>)?'
	# hash = { :name => 'name', :memories => {..} }
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

		name     = found_cpu[:name]
		memories = found_cpu[:memories]
		memories = {} if memories == nil
		
		raise ToolException.new "CPU.parse: memories for '#{name}' cpu defined in incorrect format" if memories.class != Hash
		raise ToolException.new "CPU.parse: '#{name}' cpu has no memories defined" if memories.length == 0

		return CPU.new name, memories
	end

	def CPU.known_cpus
		return @@known_cpus
	end


	@@known_cpus = {
		"pic16f1516" => {
			:aliases => [ 'p16f1516' ],
			:memories => {
				"flash" => {
					:start_address  => 0,
					:size           => 0xFFFF,
					:cell_size      => 2,         # 2 bytes
					:data_index     => 0,
					:padding        => 0x34,      # of value '0x34'
				},
				"config_words" => {
					:start_address => 0x10000,
					:size          => 32,
					:cell_size     => 1
				},
			}, # :memories
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
		return cpu if cpu

		first_name = hints.shift
		cpus.each_pair {  |c, v|
			
			found   = false
			aliases = v[:aliases]
			
			next if aliases == nil

			aliases.each  {  |a|
				found = hints.include?(a)
				break if found
			}

			return v if found
		}

		hints = [first_name, hints ].flatten
		raise ToolException.new "CPU.parse: no matching cpu found from '#{hints}'"
	end
end


[
	"helpers/tool_messages.rb",
	"helpers/variable.rb",
	"helpers/cpu.rb",
	"helpers/diff_results.rb",
].each {  |req| require "#{File.expand_path(File.dirname(__FILE__))}/#{req}" }
require "yaml"


class Tinker
	attr_accessor :name, :cpu, :variables, :raw_hex_image, :hex_file, :meta_file

	def initialize(name)
		@name          = name
		@cpu           = nil
		@variables     = []
		@raw_hex_image = []
	end

	# read variable value using 'tinker["var_name"]' syntax
	def [](var_name)
		v = get_variable var_name
		begin
			raw = cpu.memories[v.memory_name].read_object( v.address, v.size )
			return v.deserialize raw
		rescue ToolException => ex
			raise ToolException.new "Tinker: error reading variable '#{v.name}': " + ex.message
		end
	end

	# write variable value using 'tinker["var_name"] = new_value' syntax
	def []=(var_name, value)
		v = get_variable var_name
		begin
			write_value_object v, value
		rescue ToolException => ex
			raise ToolException.new "Tinker: error writing variable '#{v.name}': " + ex.message
		end
	end

	# returns the var_name matching variable instance
	def get_variable(var_name)
		var_name.downcase!
		@variables.each {  |v| return v if v.name.downcase == var_name }
		raise ToolException.new "Tinker: variable not found ('#{var_name}')"
	end

	# loads a hex-image and variable information using meta-file and returns a valid Tinker object
	def Tinker.load_image(hex_file, meta_file)
		raise ToolException.new "Tinker: hex file ('#{hex_file}') does not exists" unless File.exists? hex_file

		cpu_info, variables, is_meta_filed = Tinker.parse_meta_file meta_file
		
		raw_hex_image = File.readlines hex_file
		name          = File.basename hex_file, ".*"
		
		t = Tinker.new name
		t.cpu           = CPU.parse cpu_info
		t.variables     = variables
		t.raw_hex_image = raw_hex_image
		t.hex_file      = hex_file
		t.meta_file     = meta_file if is_meta_filed

		t.cpu.mount_hex raw_hex_image
		return t
	end

	
	def write_default_values
		variables.each {  |v|
			write_value_object v, v.default_value
		}
	end

	# dumps the image-in-memory to a hexfile
	def dump(filename)
		lines = cpu.dump_hex
		begin
			file = File.new(filename, "w")
			file.puts lines
			file.close
		rescue => ex
			file.close if file && !file.closed?
			raise ex
		end
	end

	def diff(other_file)
	end


=begin
	return differences in the base_file and other_file
	what all can differ?
		+ memory extra in 'other'
		- memory missing in 'other'
		+ memory cell extra in 'other'
		- memory cell missing in 'other'
		~ memory cell values differ
=end
	def Tinker.diff(base_file, other_file, meta)
		base_image  = Tinker.safe_load_image_file base_file, meta
		other_image = Tinker.safe_load_image_file other_file, meta

		base_memories  = base_image.cpu.memories
		other_memories = other_image.cpu.memories

		# figure out memory level diffs
		diff_results = Tinker.perform_memory_count_diff base_memories, other_memories

		# figure out memory-cell level diffs
		diff_results.push Tinker.perform_memory_cell_diff base_image.name, base_memories, other_memories

		return diff_results.flatten
	end


	def Tinker.safe_load_image_file(file, meta)
		return file if file.class == Tinker
		return Tinker.load_image file, meta		
	end

	def Tinker.perform_memory_count_diff(base_memories, other_memories)
		diff_results = []
		base_memories.each {  |base_memory|
			name = base_memory.name
			size = base_memory.size
			d    = MemoryDiff.valid_hit?( name, size, base_memory, other_memories.get_memory( name ) )
			next if d == nil
			diff_results.push d
		}

		other_memories.each {  |other_memory|
			name = other_memory.name
			size = other_memory.size
			d    = MemoryDiff.valid_hit?( name, size, base_memories.get_memory( name ), other_memory )
			next if d == nil
			diff_results.push d
		}
		return diff_results
	end

	def Tinker.perform_memory_cell_diff(base_image_name, base_memories, other_memories)
		diff_results = []

		base_memories.each {  |base_memory|
			
			name = base_memory.name
			other_memory = other_memories.get_memory name
			next if other_memory == nil

			base_length  = base_memory.contents.length
			other_length = other_memory.contents.length
			length       = base_length > other_length ? base_length : other_length
			size         = base_memory.size

			length.times {  |i|

				base_value  = base_memory.contents[i]
				other_value = other_memory.contents[i]
				address = base_memory.index_to_address i
				address = other_memory.index_to_address i if address < 0
				d = MemoryCellDiff.valid_hit? name, size, address, base_value, other_value
				next if d == nil
				d.base_name = base_image_name
				diff_results.push d
			}
		}

		return diff_results
	end




	private 
	def Tinker.parse_meta_file(raw_meta)
		meta_filed = false
		
		if raw_meta.class == String
			
			return raw_meta, [], false if raw_meta =~ /^[a-z0-9_]*$/i     # doesn't look like a flea name, must be a cpu name
			raise ToolException.new "Tinker: meta file ('#{raw_meta}') does not exists" unless File.exists? raw_meta
			raw_meta = YAML.load_file(raw_meta)[:meta]
			meta_filed = true

		elsif raw_meta.class == Hash
			raw_meta = raw_meta[:meta]
		else
			raise ToolException.new "meta_file can only be a string (cpu name/filename) or hash containing metadata"
		end
		variables = []
		symbols = raw_meta[:data]
		symbols.each_pair {  |name, raw| 
				variables.push Variable.parse name, raw
			} if symbols
		return raw_meta[:cpu], variables, meta_filed
	end

	def write_value_object(var, val)
		val = var.serialize val
		cpu.memories[var.memory_name].write_object val, var.address
	end
end

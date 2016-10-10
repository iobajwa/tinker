
[
	"helpers/tool_messages.rb",
	"helpers/variable.rb",
	"helpers/cpu.rb",
].each {  |req| require "#{File.expand_path(File.dirname(__FILE__))}/#{req}" }
require "yaml"


class Tinker
	attr_accessor :cpu,
	              :variables,       # contains a collection of all variables
	              :raw_hex_image,
	              :hex_file,
	              :meta_file

	def initialize
		@cpu = nil
		@variables = []
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
			value = v.serialize value
			cpu.memories[v.memory_name].write_object value, v.address
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
		raise ToolException.new "Tinker: meta file ('#{meta_file}') does not exists" unless File.exists? meta_file

		cpu_info, variables = Tinker.parse_meta_file meta_file
		raw_hex_image = File.readlines hex_file
		
		t = Tinker.new
		t.cpu           = CPU.parse cpu_info
		t.variables     = variables
		t.raw_hex_image = raw_hex_image
		t.hex_file      = hex_file
		t.meta_file     = meta_file

		t.cpu.mount_hex raw_hex_image
		return t
	end

	def force_default_value
		raise "Not Implemented!"
	end

	def to_hex_file(file)
		raise "Not Implemented!"
	end

	private 
	def Tinker.parse_meta_file(raw_meta)
		raw_meta = YAML.load_file(raw_meta)[:meta]
		variables = []
		symbols = raw_meta[:data]
		symbols.each_pair {  |name, raw| 
				variables.push Variable.parse name, raw
			} if symbols
		return raw_meta[:cpu], variables
	end

	def Tinker.mount_cpu_info(raw)
		return unless raw
		@cpu = CPU.parse raw
	end
end

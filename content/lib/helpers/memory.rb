
[
	"tool_messages.rb",
].each {  |req| require "#{File.expand_path(File.dirname(__FILE__))}/#{req}" }

class Memory
	attr_accessor :name, :start_address, :size, :cell_size
	attr_accessor :padding, :data_index, :endian
	attr_accessor :contents, :permissions

	def initialize(name, start_address, size, cell_size, padding=nil, data_index=0, endian=:little, contents=[])
		@name          = name
		@start_address = start_address
		@size          = size
		@contents      = contents
		@permissions   = "rw"
		@cell_size     = cell_size
		@padding       = padding
		@data_index    = data_index == nil ? 0 : data_index
		@endian        = endian
	end

	def permissions=(value)
		raise ToolException.new "Fatal error: permissions can only be passed as string" if value == nil || value.class != String
		raise ToolException.new "Fatal error: permissions can only be a collection of r/w flags" unless value =~ /^[rw]*$/i
		@permissions = value.downcase
	end

	def is_readable?
		return @permissions.include?("r")
	end

	def is_writeable?
		return @permissions.include?("w")
	end

	def is_little_endian?
		return @endian == :little
	end

	def write_byte(byte, address)
		raise ToolException.new "'#{@name}' is not writeable (permissions: '#{permissions}')" unless is_writeable?
		raise ToolException.new "address '#{address}' for '#{@name}' is beyond range" unless address_exists? address
		index = address_to_index address
		@contents[index] = byte & 0xff
	end

	def read_byte(address)
		raise ToolException.new "'#{@name}' is not readable (permissions: '#{permissions}')" unless is_readable?
		raise ToolException.new "address '#{address}' for '#{@name}' is beyond range" unless address_exists? address

		index = address_to_index address
		return @contents[index]
	end

	def write_object(raw, address)
		raise ToolException.new "'#{@name}' is not writeable (permissions: '#{permissions}')" unless is_writeable?
		raise ToolException.new "address '#{address}' for '#{@name}' is beyond range" unless address_exists? address
		index      = address_to_index address
		size_bytes = @cell_size
		raise ToolException.new "address '#{address}' for '#{@name}' is not cell-alligned" if (index % size_bytes != 0) || (index > 0 && index < size_bytes)

		# we expect to receive data in little-endian format but reverse the data-array 
		# if the memory stores it in big-endian format
		raw.reverse! unless is_little_endian?
		
		bytes = []
		if @cell_size > 1
			raw.each {  |b|
				cell    = []
				padding = @padding
				(@cell_size - 1).times {
					cell.push padding & 0xff
					padding >>= 8
				}
				cell.reverse! unless is_little_endian?
				cell.insert 0, b if @data_index == 0
				cell[@data_index] = b if @data_index != 0
				bytes.push cell
			}
			bytes.flatten!
		else
			bytes = raw
		end

		@contents[index, bytes.length] = bytes
	end

	def read_object(address, size)
		raise ToolException.new "'#{@name}' is not readable (permissions: '#{permissions}')" unless is_readable?
		raise ToolException.new "address '#{address}' for '#{@name}' is beyond range" unless address_exists? address
		index      = address_to_index address
		size_bytes = @cell_size
		raise ToolException.new "address '#{address}' for '#{@name}' is not cell-alligned" if (index % size_bytes != 0) || (index > 0 && index < size_bytes)

		bytes = []

		size.times { 
			if @cell_size == 1
				bytes.push contents[index]
				index += 1
			else
				cell = contents[ index.. index + size_bytes - 1]
				bytes.push cell[data_index]
				index += @cell_size
			end
		}

		# we expect to read data in little-endian format but reverse the data-array 
		# if the memory stores it in big-endian format
		bytes.reverse! unless is_little_endian?

		return bytes
	end

	def address_exists?(address)
		return address_to_index(address) > -1
	end


=begin
	format:
	:<name>:
		:start_address:
		:size:
		:cell_size:
		:padding:     # optional
=end
	def Memory.parse(raw, force_endian=:little)
		raise ToolException.new "Memory.parse: only Hash datatype is supported" if raw == nil || raw.class != Hash
		raise ToolException.new "Memory.parse: nothing to parse" if raw.length == 0

		name = raw.keys[0]
		meta = raw [ name ]
		name = name.to_s
		size          = meta[:size]
		start_address = meta[:start_address]
		cell_size     = meta[:cell_size]
		data_index    = meta[:data_index]
		padding       = meta[:padding]
		endian        = meta[:endian]

		raise ToolException.new "Memory.parse: size missing for '#{name}'"                      unless size
		raise ToolException.new "Memory.parse: size can only be a number ('#{name}')"           unless size.class == Fixnum
		raise ToolException.new "Memory.parse: size cannot be less than 1 ('#{name}')"          if size < 1
		raise ToolException.new "Memory.parse: start_address missing for '#{name}'"             unless start_address
		raise ToolException.new "Memory.parse: start_address can only be a number ('#{name}')"  unless start_address.class == Fixnum
		raise ToolException.new "Memory.parse: start_address cannot be less than 0 ('#{name}')" if start_address < 0
		raise ToolException.new "Memory.parse: cell_size missing for '#{name}'"                 unless cell_size
		raise ToolException.new "Memory.parse: cell_size cannot be less than 1 ('#{name}')"     if cell_size < 1
		if  cell_size > 1
			raise ToolException.new "Memory.parse: data_index missing for '#{name}'" unless data_index
			raise ToolException.new "Memory.parse: data_index cannot be less than 0 ('#{name}')" if data_index < 0
			raise ToolException.new "Memory.parse: data_index cannot be >= cell_size ('#{name}')" unless data_index < cell_size
			raise ToolException.new "Memory.parse: padding missing for '#{name}'" unless padding
			raise ToolException.new "Memory.parse: padding cannot be less than 0 ('#{name}')" if padding.class != Fixnum || padding < 0
			endian = force_endian unless endian
			raise ToolException.new "Memory.parse: endian can only be :big or :little ('#{name}')" if endian != :little && endian != :big
		else
			padding = nil
			data_index = 0
			endian = :little
		end

		return Memory.new name, start_address, size, cell_size, padding, data_index, endian
	end


	def address_to_index(address)
		end_address = @start_address + @size - 1
		return -1 if address < @start_address || address > end_address
		return address - @start_address
	end

	def index_to_address(index)
		return -1 if index < 0
		end_address = @start_address + @size - 1
		index += start_address
		return -1 if index > end_address
		return index
	end

end
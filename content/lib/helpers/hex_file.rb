
[
	"tool_messages.rb",
].each {  |req| require "#{File.expand_path(File.dirname(__FILE__))}/#{req}" }

class HexFile

	DATA_RECORD                     = 0
	END_OF_FILE_RECORD              = 1
	EXTENDED_SEGMENT_ADDRESS_RECORD = 2
	START_SEGMENT_ADDRESS_RECORD    = 3
	EXTENDED_LINEAR_ADDRESS_RECORD  = 4
	START_LINEAR_ADDRESS_RECORD     = 5
	MASK_32BIT = 0xffffffff

	def HexFile.parse(contents, &handler)
		base_address = 0
		record_counter = 0
		contents.each {  |line|

			line.strip!
			record_counter += 1
			raise ToolException.new "HexFile: damaged record # #{record_counter}, does not begin with ':" unless line.start_with? ':'
			
			begin
				encoded_checksum    = parse_byte line, line.length - 2
				calculated_checksum = HexFile.calculate_checksum line [ 1 .. line.length - 3 ]
				raise ToolException.new "checksum error (encoded: '#{encoded_checksum}', actual: '#{calculated_checksum}')" if encoded_checksum != calculated_checksum
				
				record_data_length  = parse_byte line, 1
				record_offset       = (parse_byte line, 3) << 8
				record_offset      |= parse_byte line, 5
				record_type         = parse_byte line, 7
				record_data_payload = HexFile.parse_bytes line[ 9 .. line.length - 3 ]
				raise ToolException.new "encoded data-length and parsed-data-block length does not match" if record_data_payload.length != record_data_length

				case record_type
					when DATA_RECORD
						i = 0
						record_data_payload.each {  |b| 
							address = ((base_address << 16) & MASK_32BIT) + record_offset
							handler&.call address + i, b
							i += 1
						}
					when END_OF_FILE_RECORD
						return
					when EXTENDED_LINEAR_ADDRESS_RECORD
						raise ToolException.new "record-length for 'EXTENDED_LINEAR_ADDRESS_RECORD' must be 2" unless record_data_length == 2
						base_address = ((record_data_payload[0] << 16) & MASK_32BIT) | record_data_payload[1]

					else raise ToolException.new "record-type '#{record_type}' not supported"
				end
			rescue ToolException => e
				raise ToolException.new "HexFile: record # #{record_counter}: " + e.message
			end
		}
	end

	def HexFile.parse_byte(raw, index)
		raise ToolException.new "HexFile.parse_byte: Fractured byte at index '#{index}'" unless index < raw.length - 1
		byte = raw[index..index+1]
		raise ToolException.new "HexFile.parse_byte: Corrupt byte at '#{index}'" unless byte =~ /^[0-9a-fA-F]*$/
		return byte.hex
	end

	def HexFile.calculate_checksum(raw)
		bytes = HexFile.parse_bytes raw
		checksum = 0
		bytes.each {  |b| checksum += b }
		return (~checksum + 1) & 0xff
	end

	def HexFile.parse_bytes(raw)
		raise ToolException.new "HexFile.parse_bytes: record does not contains whole bytes" if raw.length % 2 != 0

		bytes = []
		length = raw.length / 2
		i = 0

		length.times {
			bytes.push( HexFile.parse_byte raw, i )
			i += 2
		}

		return bytes
	end
end

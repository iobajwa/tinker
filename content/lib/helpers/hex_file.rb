
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
	END_OF_HEX_FILE_ENTRY = ":00000001FF"

	def HexFile.parse(contents, &handler)
		base_address = 0
		record_counter = 0
		contents.each {  |line|

			line.strip!
			record_counter += 1
			raise ToolException.new "HexFile: damaged record # #{record_counter}, does not begin with ':" unless line.start_with? ':'
			
			begin
				encoded_checksum    = parse_byte line, line.length - 2
				calculated_checksum = calculate_checksum( parse_bytes ( line [ 1 .. line.length - 3 ] ) )
				raise ToolException.new "checksum error (encoded: '#{encoded_checksum}', actual: '#{calculated_checksum}')" if encoded_checksum != calculated_checksum
				
				record_data_length  = parse_byte line, 1
				record_offset       = (parse_byte line, 3) << 8
				record_offset      |= parse_byte line, 5
				record_type         = parse_byte line, 7
				record_data_payload = parse_bytes line[ 9 .. line.length - 3 ]
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

	def HexFile.calculate_checksum(bytes)
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
			bytes.push( parse_byte raw, i )
			i += 2
		}

		return bytes
	end

=begin
	raw_blocks := {
			0 => { :start_address => 0, :contents => [] },
			1 => { :start_address => 0xff, :contents => [] },
		}
=end
	def HexFile.encode(raw_blocks, max_record_length=0x10)
		lines = []
		offset = 0
		payload = []
		raw_blocks.each_pair {  |i, meta|
			
			start_address = meta[:start_address]
			contents      = meta[:contents]

			if start_address > 0xFFFF
				lines.push generate_extended_linear_address_record_entry( start_address - 0xFFFF ) 
				offset = (( start_address >> 16 ) & 0xFFFF)
			end

			counter = 0
			while offset < contents.length
				payload, next_offset, corrected_offset = get_next_payload contents, offset, max_record_length
				lines.push serialize_payload payload, corrected_offset if payload
				offset = next_offset
			end
		}

		lines.push END_OF_HEX_FILE_ENTRY
		return lines.flatten
	end


	def HexFile.get_next_payload(raw_block, offset, max_length)
		return nil, raw_block.length, raw_block.length unless offset < raw_block.length

		payload          = raw_block [ offset .. offset + max_length - 1 ]
		nil_index        = payload.find_index nil
		corrected_offset = offset

		if nil_index == nil
			next_offset = offset + payload.length
		elsif nil_index == 0
			
			end_index  = payload.find_index {  |v| v != nil }
			end_index  = max_length if end_index == nil || end_index == 0 || end_index < nil_index
			offset    += end_index

			return get_next_payload raw_block, offset, max_length
		else
			nil_end_index = raw_block [ offset + nil_index .. raw_block.length ].find_index {  |v| v != nil  }
			next_offset   = nil_end_index == nil ? raw_block.length : offset + nil_end_index + nil_index
			payload       = payload [ 0 .. nil_index - 1]
		end

		return payload, next_offset, corrected_offset
	end

	def HexFile.serialize_payload(payload, offset, record_type=DATA_RECORD)
		checksum = calculate_checksum [ payload.length, h16_to_a_bigend( offset ), record_type, payload ].flatten
		line = ":" + hex_to_s( payload.length ) + hex_to_s( offset, 4 ) + hex_to_s( record_type )
		payload.each {  |byte|
			line += hex_to_s byte
		}
		line += hex_to_s checksum
		return line
	end

	def HexFile.generate_extended_linear_address_record_entry(address_offset)
		return serialize_payload( h16_to_a_bigend( address_offset ), 0, EXTENDED_LINEAR_ADDRESS_RECORD )
	end

	def HexFile.hex_to_s(value, digits=2)
		return sprintf("%0#{digits}X", value)
	end

	def HexFile.h16_to_a_bigend(value)
		return [ (value >> 8) & 0xff, value & 0xff ]
	end

	def HexFile.END_OF_HEX_FILE_ENTRY
		return END_OF_HEX_FILE_ENTRY
	end

end

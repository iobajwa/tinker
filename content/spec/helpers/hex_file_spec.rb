
require "spec_helper"
require "helpers/hex_file"

describe HexFile do
	describe "when parsing records" do
		describe "should raise error when" do
			it "a line does not begin with ':'" do
				expect{ HexFile.parse ["blah"] }.to raise_exception(ToolException, "HexFile: damaged record # 1, does not begin with ':")
			end

			it "record length and number of data bytes do not match" do
				dummy_record = [":11000800803120007F08F30011080139F200210036"]
				
				expect { HexFile.parse dummy_record }.to raise_exception(ToolException, "HexFile: record # 1: encoded data-length and parsed-data-block length does not match")
			end

			it "unsupported record-type is encoded" do
			end
		end

		it "parses each data record and invokes the lambda when one is present" do
			dummy_record = [":10000800803120007F08F30011080139F200210037"]
			parsed_data = []
			HexFile.parse(dummy_record) {  |address, byte|
				parsed_data[address] = byte
			}

			parsed_data.should be == [nil, nil, nil, nil, nil, nil, nil, nil, 0x80, 0x31, 0x20, 0x00, 0x7F, 0x08, 0xF3, 0x00, 0x11, 0x08, 0x01, 0x39, 0xF2, 0x00, 0x21, 0x00]
		end

		describe "with extended-linear-address record" do
			it "raises exception when record-length is not equal to 2" do
				expect { HexFile.parse [":0100000401FA"] }.to raise_exception(ToolException, "HexFile: record # 1: record-length for 'EXTENDED_LINEAR_ADDRESS_RECORD' must be 2")
			end

			it "parses the record and adjusts the addresses of future data records accordingly" do
				dummy_record = [":10000000803120007F08F30011080139F20021003F   ",
								":020000040001F9\n",
								":01010000AA54  \n",
							   ]
				parsed_data1 = []
				parsed_data2 = []
				HexFile.parse(dummy_record) {  |address, byte|
					if address < 0xFFFF
						parsed_data1[address] = byte
					else
						parsed_data2[address - 65792] = byte
					end
				}

				parsed_data1.should be == [0x80, 0x31, 0x20, 0x00, 0x7F, 0x08, 0xF3, 0x00, 0x11, 0x08, 0x01, 0x39, 0xF2, 0x00, 0x21, 0x00]
				parsed_data2.should be == [0xAA]
			end
		end
	end

	describe "when parsing byte" do
		describe "should raise exception when" do
			it "length of passed string is less than that required" do
				expect { HexFile.parse_byte("1", 0) }.to raise_exception(ToolException, "HexFile.parse_byte: Fractured byte at index '0'")
			end

			it "string contains non-hexadecimal chars" do
				expect { HexFile.parse_byte("0123AG", 4) }.to raise_exception(ToolException, "HexFile.parse_byte: Corrupt byte at '4'")
			end
		end

		it "should return valid result" do
			HexFile.parse_byte("ab12", 2).should be == 0x12
		end
	end

	describe "when parsing byte arrays" do
		it "should raise exception when length of passed string is not multiple of 2" do
			expect { HexFile.parse_bytes "123" }.to raise_exception(ToolException, "HexFile.parse_bytes: record does not contains whole bytes")
		end
		it "should return correct array as result" do
			bytes = HexFile.parse_bytes "1234567890"
			bytes.should be == [0x12, 0x34, 0x56, 0x78, 0x90]
		end
	end

	it "when calculating checksum should return correct result" do
		bytes = [0x10, 0x00, 0x08, 0x00, 0x80, 0x31, 0x20, 0x00, 0x7F, 0x08, 0xF3, 0x00, 0x11, 0x08, 0x01, 0x39, 0xF2, 0x00, 0x21, 0x00]
		HexFile.calculate_checksum(bytes).should be == 0x37
	end

	describe "when encoding memory contents to hex format" do
		describe "and serializing a payload" do
			it "returns correct result" do
				payload = [ 0, 1, 2, 3, 4, 5 ]
				
				serialized_line = HexFile.serialize_payload payload, 0x1234, 0x55

				serialized_line.should be == ":0612345500010203040550"
			end
		end

		describe "and obtaining the next payload, it returns correct result when" do
			it "returns nil when all entries have ben extracted" do
				raw_block = (0..19).to_a

				payload, offset, corrected_offset = HexFile.get_next_payload raw_block, 20, 5

				payload.should be_nil
				offset.should be == 20
				corrected_offset.should be == 20
			end

			it "raw_block contains more entries than requested" do
				raw_block = (0..19).to_a

				payload, new_offset, corrected_offset = HexFile.get_next_payload raw_block, 2, 5

				payload.should be == [2, 3, 4, 5, 6]
				new_offset.should be == 7
				corrected_offset.should be == 2
			end

			it "raw_block contains less entries than requested" do
				raw_block = (0..4).to_a

				payload, new_offset, corrected_offset = HexFile.get_next_payload raw_block, 0, 10

				payload.should be == [0, 1, 2, 3, 4]
				new_offset.should be == 5
				corrected_offset.should be == 0
			end

			describe "raw_block contains more entries than requested" do
				describe "but we encounter a nil element" do
					it "followed by non-nil elements" do
						raw_block = [0, 1, 2, 3, 4, 5, nil, nil, nil, 9, 10]

						payload, new_offset, corrected_offset = HexFile.get_next_payload raw_block, 0, 8

						payload.should be == [0, 1, 2, 3, 4, 5]
						new_offset.should be == 9
						corrected_offset.should be == 0
					end

					it "followed by all nil elements" do
						raw_block = [0, 1, 2, 3, 4, 5, nil, nil, nil, nil, nil]

						payload, new_offset, corrected_offset = HexFile.get_next_payload raw_block, 4, 3

						payload.should be == [4, 5]
						new_offset.should be == 11
						corrected_offset.should be == 4
					end
				end

				it "and offset points in middle of all nil elements" do
					raw_block = [0, 1, 2, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil ]

					payload, new_offset, corrected_offset = HexFile.get_next_payload raw_block, 5, 0x10

					payload.should be_nil
					new_offset.should be == raw_block.length
					corrected_offset.should be == raw_block.length
				end

				# it "test" do
				# 	raw_block = [148, 49, 237, 44, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, 192, 48, 244, 0, 116, 8, 139, 4, 8, 0, 139, 49, 67, 35, 146, 49, 139, 49, 143, 35, 8, 0, 146, 49, 0, 34, 146, 49, 134, 49, 231, 38, 8, 0, 255, 48, 244, 0, 116, 8, 33, 0, 204, 0, 8, 0, 120, 18, 33, 0, 189, 1, 202, 1, 202, 10, 8, 0, 119, 8, 118, 4, 0, 48, 3, 29, 1, 48, 8, 0, 254, 0, 18, 0, 30, 0, 254, 11, 31, 42, 0, 52, 100, 0, 128, 1, 1, 49, 137, 11, 37, 42, 0, 52, 245, 0, 117, 8, 244, 0, 116, 8, 33, 0, 238, 0, 8, 0, 34, 0, 173, 1, 173, 10, 33, 0, 202, 1, 202, 10, 8, 0, 120, 8, 240, 57, 3, 56, 248, 0, 33, 0, 187, 1, 189, 1, 8, 0, 150, 49, 28, 38, 146, 49, 33, 0, 73, 8, 129, 49, 0, 33, 8, 0, 33, 0, 65, 8, 3, 25, 78, 42, 1, 48, 8, 0, 0, 48, 8, 0, 146, 49, 137, 34, 146, 49, 33, 0, 141, 20, 8, 48, 137, 49, 180, 33, 8, 0, 34, 0, 173, 8, 3, 29, 8]

				# 	payload, new_offset, corrected_offset = HexFile.get_next_payload raw_block, 0, 0x10
				# end
			end
		end

		describe "and generating extended-linear-address-record-entry" do
			it "returns correct result" do
				generated_entry = HexFile.generate_extended_linear_address_record_entry 0x1234

				generated_entry.should be == ":020000041234B4"
			end
		end
	end
end

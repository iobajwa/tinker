
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
				dummy_record = [":10000000803120007F08F30011080139F20021003F",
								":020000040001F9",
								":10000000803120007F08F30011080139F20021003F",
							   ]
				parsed_data1 = []
				parsed_data2 = []
				HexFile.parse(dummy_record) {  |address, byte|
					if address < 0xFFFF
						parsed_data1[address] = byte
					else
						parsed_data2[address - 65536] = byte
					end
				}

				parsed_data1.should be == [0x80, 0x31, 0x20, 0x00, 0x7F, 0x08, 0xF3, 0x00, 0x11, 0x08, 0x01, 0x39, 0xF2, 0x00, 0x21, 0x00]
				parsed_data2.should be == [0x80, 0x31, 0x20, 0x00, 0x7F, 0x08, 0xF3, 0x00, 0x11, 0x08, 0x01, 0x39, 0xF2, 0x00, 0x21, 0x00]
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
		HexFile.calculate_checksum("10000800803120007F08F30011080139F2002100").should be == 0x37
	end
end

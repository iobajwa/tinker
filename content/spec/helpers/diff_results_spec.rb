
require "spec_helper"
require "helpers/diff_results"

describe MemoryDiff do
	describe "when instantiating an instance" do
		it "returns nil when both the memories are present" do
			d = MemoryDiff.valid_hit? 'flash', 0xffff, 'one', 'two'
			d.should be_nil
		end
		it "returns nil when both the memories are nil" do
			d = MemoryDiff.valid_hit? 'flash', 0xffff, nil, nil
			d.should be_nil
		end
		it "returns valid object ref with '-' diff when memory is missing" do
			d = MemoryDiff.valid_hit? 'flash', 0xffff, 'base', nil
			d.memory_name.should be == 'flash'
			d.memory_size.should be == 0xffff
			d.diff_type.should be == '-'
		end
		it "returns valid object ref with '+' diff when memory is extra" do
			d = MemoryDiff.valid_hit? 'flash', 0xffff, nil, 'other'
			d.memory_name.should be == 'flash'
			d.memory_size.should be == 0xffff
			d.diff_type.should be == '+'
		end
	end
	describe "when converting the diff to string, returns correct string when" do
		it "other is missing" do
			d = MemoryDiff.new 'flash', 0xffff, '-'
			d.to_s.should be == "- flash (65535 bytes)"
		end
		it "base is missing" do
			d = MemoryDiff.new 'flash', 0xffff, '+'
			d.to_s.should be == "+ flash (65535 bytes)"
		end
	end
end

describe MemoryCellDiff do
	describe "when instantiating an instance" do
		it "returns nil when both the cells are equal" do
			d = MemoryCellDiff.valid_hit? 'flash', 0xffff, 23, 'a', 'a'
			d.should be_nil
		end
		it "returns valid object ref with '-' diff when cell is missing" do
			d = MemoryCellDiff.valid_hit? 'flash', 0xffff, 23, 'base', nil
			d.memory_name.should be == 'flash'
			d.memory_size.should be == 0xffff
			d.diff_type.should be == '-'
			d.base_value.should be == 'base'
			d.other_value.should be_nil
		end
		it "returns valid object ref with '+' diff when cell is extra" do
			d = MemoryCellDiff.valid_hit? 'flash', 0xffff, 23, nil, 'other'
			d.memory_name.should be == 'flash'
			d.memory_size.should be == 0xffff
			d.diff_type.should be == '+'
			d.base_value.should be_nil
			d.other_value.should be == 'other'
		end
		it "returns valid object ref with '~' diff when cell values don't match" do
			d = MemoryCellDiff.valid_hit? 'flash', 0xffff, 23, 'base', 'other'
			d.memory_name.should be == 'flash'
			d.memory_size.should be == 0xffff
			d.diff_type.should be == '~'
			d.base_value.should be == 'base'
			d.other_value.should be == 'other'
		end
	end
	describe "when converting the diff to string, returns correct string when" do
		it "neither cell is nil" do
			d = MemoryCellDiff.new 'flash', 0xffff, '~', 23, 2, 3
			d.to_s.should be == "~ flash @ 0x0017 : '0x03' (base is '0x02')"
		end
		it "first cell is nil" do
			d = MemoryCellDiff.new 'flash', 0xff, '+', 1, nil, 0x12
			d.to_s.should be == "+ flash @ 0x0001 : '0x12'"
		end
		it "second cell is nil" do
			d = MemoryCellDiff.new 'flash', 0xff, '-', 1, 0x45, nil
			d.to_s.should be == "- flash @ 0x0001 : '0x45'"
		end
	end
end

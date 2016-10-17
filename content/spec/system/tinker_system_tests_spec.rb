
require "spec_helper"
require "tinker"

describe Tinker do
	describe "when running the tool with" do
		before(:all) do
			@base_path = File.dirname(__FILE__)
			@bin_dir   = Dir.pwd + "/bin"
			Dir.mkdir(@bin_dir) unless File.directory?(@bin_dir)
		end

		it "should deserialize-serialize the same file without any changes" do
			hex_file        = get_artefacts_full_path 'sample.hex'
			output_hex_file = get_bin_full_path 'sample_dump.hex'

			Tinker.load_image( hex_file, "pic16f1516" ).dump( output_hex_file )

			IO.read(output_hex_file).should be == IO.read(hex_file)
		end

		it "should deserialize-serialize the same file without any changes" do
			hex_file        = get_artefacts_full_path 'sample.hex'
			meta_file       = get_artefacts_full_path 'sample.meta.yaml'
			output_hex_file = get_bin_full_path 'sample_changed.hex'
			remove_file output_hex_file

			t = Tinker.load_image hex_file, meta_file
			t["voltage"] = 213
			t.dump output_hex_file

			t = Tinker.load_image output_hex_file, meta_file
			t["voltage"].should be == 213

			# make sure we altered only a single cell
			diffs = Tinker.diff hex_file, output_hex_file, meta_file
			diffs.length.should be == 1
			diffs[0].to_s.should be == "~ flash @ 0x3F00 : '0xD5' (sample is '0xE6')"
		end
	end

	def get_artefacts_full_path(file)
		return @base_path + "/artefacts/" + file
	end

	def get_bin_full_path(file)
		return @bin_dir + "/" + file
	end

	def remove_file(file)
		File.delete file if File.exist? file
	end

end

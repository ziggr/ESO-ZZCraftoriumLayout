#! /usr/bin/python3
#
# python3 parser <input.txt> <output.lua>
#
import sys



def main():
	print("Cheers luv!")
	if len(sys.argv) < 3:
		sys.stderr.write("Usage: python3 Parser.py <inputfile> <outputfile>")
		sys.exit(1)

	input_filepath = sys.argv[1]
	output_filepath = sys.argv[2]

	print("in:{}  out:{}".format(input_filepath, output_filepath))

main()

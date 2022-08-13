# quick rules to build the metal shader library
# lots of posts on the internet claiming SPM does this
# automatically: I think all these people really are
# confused and are using Xcode...

.PHONY: all
	
shader_dir := Sources/MetalEngine/Metal

metal := ${shader_dir}/Shaders.metal

metallib := ${shader_dir}/default.metallib

tmpfile := Lib.air

all: ${metallib}
	swift run

${metallib}: ${metal}
	xcrun metal -c $^ -o ${tmpfile}
	xcrun metallib ${tmpfile} -o $@
	rm ${tmpfile}

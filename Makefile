# quick rules to build the metal shader library
# lots of posts on the internet claiming SPM does this
# automatically: I think all these people really are
# confused and are using Xcode...

.PHONY: all
	
shader_dir := Sources/MetalEngine/Metal

metal := ${shader_dir}/Shaders.metal

metalinclude := Sources/CMetalEngine

metalheader := ${metalinclude}/ShaderTypes.h

metallib := ${shader_dir}/default.metallib

tmpfile := Lib.air

all: ${metallib}
	swift run

${metallib}: ${metal} ${metalheader}
	xcrun metal -c ${metal} -o ${tmpfile} -I${metalinclude}
	xcrun metallib ${tmpfile} -o $@
	rm ${tmpfile}

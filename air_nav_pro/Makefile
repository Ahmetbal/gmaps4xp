all: air_navigation_linux  

clean: clean_air_navigation_linux

##############################
#######  TARGET: air_navigation_linux
##############################
TOP_air_navigation_linux=./
WD_air_navigation_linux=$(shell cd ${TOP_air_navigation_linux};echo `pwd`)
cpp_SRC_air_navigation_linux+=${WD_air_navigation_linux}/air_navigation_linux.cpp
cpp_SRC_air_navigation_linux+=${WD_air_navigation_linux}/core.cpp

OBJS_air_navigation_linux+=$(cpp_SRC_air_navigation_linux:.cpp=.cpp.o)

CFLAGS_air_navigation_linux+= -iquote./\
 -iquoteSDK/CHeaders/XPLM\
 -iquoteSDK/CHeaders/Widgets\
 -iquote- -iquote/usr/include/\
 -DIBM=0 -DAPL=0 -DLIN=1\
 -DXPLM200

DBG=-g

CFLAGS_air_navigation_linux+=-O0 -x c++ -ansi

clean_air_navigation_linux:
	rm -fv *.o *.d air_navigation_linux.xpl

air_navigation_linux:
	$(MAKE) air_navigation_linux.xpl TARGET=air_navigation_linux.xpl CC="g++"  LD="g++"  AR="ar -crs"  SIZE="size" LIBS+="-lpthread -lm"

air_navigation_linux.xpl: ${OBJS_air_navigation_linux}
	${CC} -shared 	${LDFLAGS}	-o air_navigation_linux.xpl 	${OBJS_air_navigation_linux} ${LIBS}

air_navigation_linux.exe: ${OBJS_air_navigation_linux}
	${CC} ${LDFLAGS}		-o air_navigation_linux.exe 	${WD_air_navigation_linux}/core.cpp.o ${LIBS}


ifeq (${TARGET}, air_navigation_linux.xpl)

%.cpp.o: %.cpp
	gcc -Wall -c -fPIC ${CFLAGS_air_navigation_linux} $< -o $@ -MMD
include $(cpp_SRC_air_navigation_linux:.cpp=.d)

%.d: %.cpp
	set -e; $(CC) -M $(CFLAGS_air_navigation_linux) $<  | sed 's!\($(*F)\)\.o[ :]*!$(*D)/\1.o $@ : !g' > $@;  [ -s $@ ] || rm -f $@

endif
# end Makefile

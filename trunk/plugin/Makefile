all: gmaps

clean: clean_gmaps

##############################
#######  TARGET: gmaps
##############################
TOP_gmaps=./
WD_gmaps=$(shell cd ${TOP_gmaps};echo `pwd`)
cpp_SRC_gmaps+=${WD_gmaps}/gmaps.cpp

OBJS_gmaps+=$(cpp_SRC_gmaps:.cpp=.cpp.o)

CFLAGS_gmaps+= -iquote./\
 -iquoteSDK/CHeaders/XPLM\
 -iquoteSDK/CHeaders/Widgets\
 -iquote- -iquote/usr/include/\
 -DIBM=0 -DAPL=0 -DLIN=1\
 -DXPLM200

DBG=-g

CFLAGS_gmaps+=-O0 -x c++ -ansi

clean_gmaps:
	rm -f ${OBJS_gmaps}
	rm -f gmaps.cpp.d
	rm -f gmaps.d

gmaps:
	$(MAKE) gmaps.xpl TARGET=gmaps.xpl\
 CC="g++"  LD="g++"  AR="ar -crs"  SIZE="size" LIBS+="-lGL -lGLU -ljpeg"

gmaps.xpl: ${OBJS_gmaps}
	${CC} -shared ${LDFLAGS} -o gmaps.xpl ${OBJS_gmaps} ${LIBS}


ifeq (${TARGET}, gmaps.xpl)

%.cpp.o: %.cpp
	gcc -c -fPIC ${CFLAGS_gmaps} $< -o $@ -MMD
include $(cpp_SRC_gmaps:.cpp=.d)

%.d: %.cpp
	set -e; $(CC) -M $(CFLAGS_gmaps) $< \
 | sed 's!\($(*F)\)\.o[ :]*!$(*D)/\1.o $@ : !g' > $@; \
 [ -s $@ ] || rm -f $@

endif
# end Makefile

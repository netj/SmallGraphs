# Makefile for Green-Marl(C++) SmallGraph driver

CXXFLAGS := -g -Wall -fopenmp
LDFLAGS := 

# compile Green-Marl
all: libsmallgraph.so

libsmallgraph.so: smallgraph.o match.o main.o
	$(CXX) -o $@ -shared $(LDFLAGS) $^

.cc.o:
	$(CXX) -o $@ -c $(CXXFLAGS) $<

main.cc: smallgraph.h

smallgraph.h \
smallgraph.cc:
	# TODO gm_comp -o=. -t=cpp_omp  smallgraph.gm
	touch $@


clean:
	rm -f smallgraph.{cc,h} *.o libsmallgraph.so a.out

test:
	$(CXX) $(CXXFLAGS) test.cc match.cc && ./a.out


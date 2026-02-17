TARGET = bin/working_version

CC ?= gcc
CXX ?= g++
OBJCOPY ?= objcopy

CXXFLAGS := $(shell pkg-config --cflags rocksdb)
CXXFLAGS += -I./include
ifneq ($(.SHELLSTATUS),0)
$(error pkg-config failed)
endif

LIBS := $(shell pkg-config --static --libs rocksdb)
ifneq ($(.SHELLSTATUS),0)
$(error pkg-config failed)
endif

CXXFLAGS +=  $(EXTRA_CXXFLAGS)
LDFLAGS +=  $(EXTRA_LDFLAGS)

SOURCES := $(wildcard src/*.cc)
OBJECTS := $(SOURCES:.cc=.o)

all: $(TARGET) $(TARGET).dbg

$(TARGET).dbg: $(TARGET)
	@$(OBJCOPY) --only-keep-debug $(TARGET) $(TARGET).dbg
	@$(OBJCOPY) --strip-all $(TARGET)

debug: $(TARGET)

$(TARGET): $(OBJECTS)
	$(CXX) $(CXXFLAGS) -g -o $(TARGET) $(OBJECTS) $(LIBS) $(LDFLAGS)

src/%.o: src/%.cc
	$(CXX) $(CXXFLAGS) -g -c $< -o $@

clean:
	$(RM) $(TARGET) $(TARGET).dbg $(OBJECTS)

.PHONY: all debug clean
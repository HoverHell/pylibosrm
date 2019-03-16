#-------------------------------------------------
#
# Project created by QtCreator 2019-03-16T15:52:40
#
#-------------------------------------------------

QT       -= core gui

TARGET = pylibosrm
TEMPLATE = lib

DEFINES += PYLIBOSRM_LIBRARY

SOURCES += \
    pylibosrm/osrm_simple.cpp \
    pylibosrm/osrm_wrapper.cpp

HEADERS +=

unix {
#    target.path = /usr/lib
#    INSTALLS += target
}

unix:!macx: LIBS += -L$$OUT_PWD/./ -lpylibosrm

# TODO:
# x86_64-linux-gnu-gcc \
#     -pthread -DNDEBUG -g -fwrapv -O2 -Wall -g -fstack-protector-strong \
#     -Wformat -Werror=format-security -Wdate-time \
#     -D_FORTIFY_SOURCE=2 -fPIC \
#     -Ipylibosrm -I/home/hell/.virtualenv/lib/python3.8/site-packages/numpy/core/include \
#     -I./osrm-backend/include -I./osrm-backend/third_party/variant/include -I/home/hell/.virtualenv/include \
#     -I/usr/include/python3.8m \
#     -c pylibosrm/osrm_wrapper.cpp -o build/temp.linux-x86_64-3.8/pylibosrm/osrm_wrapper.o \
#     -fopenmp -std=c++14
# x86_64-linux-gnu-g++ \
#     -pthread -shared -Wl,-O1 -Wl,-Bsymbolic-functions -Wl,-Bsymbolic-functions -Wl,-z,relro -Wl,-Bsymbolic-functions -Wl,-z,relro \
#     -g -fstack-protector-strong \
#     -Wformat -Werror=format-security -Wdate-time \
#     -D_FORTIFY_SOURCE=2 \
#     build/temp.linux-x86_64-3.8/pylibosrm/osrm_wrapper.o \
#     -L./osrm-backend/build \
#     -l:libosrm.a \
#     -lboost_regex -lboost_date_time -lboost_chrono -lboost_filesystem -lboost_iostreams -lboost_thread -lboost_system \
#     -lpthread -ltbb -ltbbmalloc -lrt -lz \
#     -o build/lib.linux-x86_64-3.8/pylibosrm/osrm_wrapper.cpython-38m-x86_64-linux-gnu.so \
#     -fopenmp

INCLUDEPATH += $$PWD/osrm-backend/include ./osrm-backend/third_party/variant/include
DEPENDPATH += $$PWD/.

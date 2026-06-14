cmake_minimum_required(VERSION 3.21)

project(FloatingCountdownQt VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 6.5 REQUIRED COMPONENTS Quick)

qt_standard_project_setup(REQUIRES 6.5)

qt_add_executable(FloatingCountdown
    src/main.cpp
)

qt_add_qml_module(FloatingCountdown
    URI FloatingCountdown
    VERSION 1.0
    QML_FILES
        qml/Main.qml
)

target_link_libraries(FloatingCountdown
    PRIVATE Qt6::Quick
)

set_target_properties(FloatingCountdown PROPERTIES
    WIN32_EXECUTABLE TRUE
    MACOSX_BUNDLE TRUE
    MACOSX_BUNDLE_GUI_IDENTIFIER com.kicocolor.FloatingCountdown
    MACOSX_BUNDLE_BUNDLE_NAME FloatingCountdown
)

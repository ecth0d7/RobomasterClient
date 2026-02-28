# RobomasterClient
## 项目概述
本项目是基于Qt 6.9.3开发的客户端应用，采用CMake构建系统，集成了MQTT通信（基于Protobuf协议）、UDP视频流接收解码、QML前端交互、输入设备监听以及自定义视频流传输（RoboSever）等核心功能，各模块按功能拆分至不同文件夹，保证代码结构清晰、职责单一。

## 编译说明
### 环境前置要求
1. Qt版本：**Qt 6.9.3**（需包含Core、Widgets、Network、Gui、Quick、QuickControls2、QuickLayouts等组件）；
2. 依赖库：FFmpeg（libavcodec/libavformat/libavutil/libswscale）、Mosquitto（MQTT）、Protobuf、PkgConfig；
3. 编译器：支持C++17标准的GCC/Clang（推荐GCC 9+）。
### 客户端运行
```bash
#进入项目的目录后(基于本地ip：127.0.0.1，端口为：3333（mqtt），8888（udp）构建)
./RoboMasterMqttTest
```
### 客户端编译（Qt Creator + CMake）（支持各种个性化设置）
1. 打开Qt Creator，点击「打开项目」，选择项目根目录下的`CMakeLists.txt`文件；
2. 确认项目构建套件（Kit）已关联Qt 6.9.3版本，若Qt6路径未自动识别，需手动指定：
   在CMake配置中添加`Qt6_DIR`变量，值为Qt 6.9.3的cmake目录（如`/home/yourname/Qt/6.9.3/gcc_64/lib/cmake/Qt6`）；
3. 点击「构建」按钮（或快捷键Ctrl+B），CMake会自动解析依赖、生成编译文件并完成编译；
4. 编译完成后可直接点击「运行」按钮启动客户端。

### RoboSever编译运行（命令行方式）
RoboSever作为自定义视频流传输服务端，需通过命令行在项目根目录执行以下步骤：
```bash
# 清理旧构建文件（可选，确保编译环境干净）
rm -rf build
# 创建并进入build目录
mkdir -p build && cd build
# 执行CMake生成Makefile（关联项目根目录的CMake配置）
cmake ..
# 编译源码（-j后接核心数，加速编译，如-j4）
make -j4
# 运行RoboSever可执行文件
./sever
```

## 文件夹结构及功能说明
### 1. mqtt/
该目录下按代码类型拆分，核心实现基于Mosquitto的MQTT通信能力，结合Protobuf序列化协议，为前端QML提供信号槽交互接口：
- `protocol/`：原协议定义基础上，补充`protobuf/`子目录，存放`robomaster_custom_client.proto`协议文件，定义MQTT消息的Protobuf序列化格式；
- `include/`：存放MQTT模块头文件，包含`IMqttHandler.h`（处理器抽象接口）、`MqttClient.h`（核心客户端）、`MqttRecvHandlers.h/MqttSendHandlers.h`（收发处理器声明）；
- `src/`：存放MQTT模块源文件，实现核心逻辑：
  - 核心设计：`MqttClient`作为核心客户端维护MQTT连接，`MqttRecvHandlers/MqttSendHandlers`分别处理消息接收和发送，解耦不同业务的消息处理逻辑；
  - 序列化：基于Protobuf自动生成的代码，完成MQTT消息的序列化/反序列化；
  - 交互设计：基于Qt信号槽机制封装，将MQTT消息状态、收发结果等封装为信号供QML调用，同时提供槽函数支持QML触发消息发送。

### 2. udp/
该目录实现UDP视频流的接收、解码及QML图像渲染能力：
- `include/`：存放`VideoReceiver.h`（UDP视频接收）、`VideoImageProvider.h`（QML图像提供器）头文件；
- `src/`：存放UDP视频流处理源文件，实现核心逻辑：
  - 接收逻辑：`VideoReceiver`基于Qt Network的QUdpSocket绑定端口，异步监听UDP视频数据报，结合FFmpeg完成视频帧的接收和缓冲；
  - 解码逻辑：通过FFmpeg的libavcodec/libavformat/libavutil/libswscale库，对UDP接收的二进制视频数据进行解码，转换为可渲染的图像帧；
  - QML交互：`VideoImageProvider`将解码后的视频帧封装为QML可调用的图像提供器，实现在QML界面实时渲染视频流。

### 3. qml/
该目录是项目的前端界面模块，基于Qt QML实现可视化交互，同时集成C++层扩展能力：
- `qrc/`：存放`qml_resources.qrc`资源文件，管理QML界面的资源依赖；
- `components/`：按功能拆分 QML 子组件（主界面、视频展示、设备控制等），基于 Quick 系列组件复用；
    - 模块拆分：按功能拆分为多个QML子模块（主界面、视频展示、设备控制等），基于Quick/QuickControls2/QuickLayouts实现组件化复用；
    - MQTT交互：QML层绑定C++ MQTT模块的信号/槽，实现MQTT消息的实时展示（接收器），并通过定时器按协议指定Hz触发MQTT消息发送（发送器）。
    - UDP交互：绑定UDP信号槽，实现视频流的接收。
- `include/`：存放`GlobalInputFilter.h`（全局输入过滤）头文件；
- `src/`：实现C++输入监听并封装为QML接口：输入监听：`GlobalInputFilter`实现全局键盘/鼠标监听，通过Qt事件过滤机制捕获键盘事件，同时采用持续捕获鼠标的方式，满足精准交互场景（如设备操控），并通过信号槽将输入事件传递给QML层；
 
### 4. RoboSever/
该目录是自定义的视频流传输服务端模块，实现视频数据的采集、编码、传输能力：
- 编译运行：需在项目根目录通过命令行编译（`rm -r build&&cmake ..&&make&&./sever`），依赖FFmpeg完成视频编码；
- 核心逻辑：
  - 视频源采集：对接本地摄像头/远程视频源，基于FFmpeg捕获原始视频帧；
  - 编码传输：对原始视频帧进行H.264/H.265编码，通过自定义UDP/TCP协议将视频流传输至客户端；
  - 服务端管理：实现轻量级服务端逻辑，处理客户端连接、鉴权、视频流订阅/取消订阅，维护连接状态。

## 核心构建逻辑（CMake关键配置）
1. 依赖管理：通过PkgConfig查找FFmpeg、Mosquitto，通过find_package查找Qt6、Protobuf；
2. Protobuf代码生成：自动编译`.proto`文件生成C++序列化/反序列化代码，并加入编译列表；
3. 编译选项：启用C++17标准，针对GCC/Clang添加`-O3`优化、编译警告屏蔽（如废弃声明、未使用参数）；
4. 部署配置：通过`qt_generate_deploy_app_script`生成Qt应用部署脚本，自动处理依赖库部署；
5. QML路径：设置`QML_IMPORT_PATH`指定QML模块导入路径，确保QML组件可正常引用。

## 注意事项
1. 编译前需确保Qt 6.9.3的CMake路径正确，且已安装所有依赖库（FFmpeg、Mosquitto、Protobuf）；
2. RoboSever运行前需确认端口未被占用，且客户端与服务端的视频流传输协议（编码格式、端口、Hz）保持一致；
3. Protobuf生成的代码会输出到`CMAKE_CURRENT_BINARY_DIR`，需确保该目录被加入头文件搜索路径；
4. 键盘/鼠标捕获功能在不同操作系统（Windows/Linux/macOS）下权限不同，Linux需确保有输入设备访问权限，macOS/Windows需适配系统事件机制；
5. 编译RoboSever时，若出现FFmpeg链接错误，需确认`pkg-config`能正确识别FFmpeg库路径，或手动指定库路径。
6. 该项目未完善，部分UI还未实现。
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    id:root
    objectName:"mobileCameraProjectionSetup"
    property var host:null
    property bool editable:false
    property string configurationFile:""
    property string modelFile:""
    property var initial:({})
    property var values:({})
    property string feedback:""
    signal saved(string file)
    spacing:8
    function put(key,value){values=Object.assign({},values,{[key]:value});feedback="";}
    function load(){
        initial=host?.projectionConfiguration(configurationFile)??{};
        const k=initial.normalized_intrinsics??[];
        values=Object.assign({fx:k[0]??'',fy:k[1]??'',cx:k[2]??'.5',cy:k[3]??'.5',
            camera_height_m:'',pitch_down_deg:'',camera_yaw_offset_deg:0,roll_clockwise_deg:0,
            calibration_id:'',gimbal_node_id:'',gimbal_source_id:''},initial);
        feedback='';
    }
    function configuration(){
        const result=Object.assign({},initial,{enabled:enableProjection.checked,acknowledged:acknowledged.checked,
            image_model_confirmed:imageConfirmed.checked,rigid_camera_confirmed:rigid.checked,
            frame_id:frame.currentText,method:'ground-plane',calibration_id:String(values.calibration_id??'').trim(),
            pose_heading_clockwise:yawDirection.currentIndex===0,
            normalized_intrinsics:['fx','fy','cx','cy'].map(k=>Number(values[k])),
            gimbal_node_id:String(values.gimbal_node_id??'').trim(),gimbal_source_id:String(values.gimbal_source_id??'').trim()});
        for(const key of ['camera_height_m','pitch_down_deg','camera_yaw_offset_deg','roll_clockwise_deg'])result[key]=Number(values[key]);
        return result;
    }
    readonly property string formError:{
        if(!enableProjection.checked)return '';
        if(!acknowledged.checked || !imageConfirmed.checked)return '请确认相机参数、地面假设及当前输入图像模型。';
        if(yawDirection.currentIndex<0)return '请选择本车朝向角度的正方向。';
        for(const key of ['fx','fy','cx','cy','camera_height_m','pitch_down_deg','camera_yaw_offset_deg','roll_clockwise_deg'])
            if(String(values[key]??'').trim()==='' || !Number.isFinite(Number(values[key])))return '请完整填写数值参数；未收到的值不会补零。';
        if(Number(values.fx)<=.05 || Number(values.fy)<=.05 || Number(values.camera_height_m)<=.05)return '焦距和相机高度必须为有效正值。';
        if(!String(values.calibration_id??'').trim() || values.calibration_id==='unconfigured')return '请填写用于追溯的相机配置标识。';
        if(!rigid.checked && (!String(values.gimbal_node_id??'').trim() || !String(values.gimbal_source_id??'').trim()))return '可转动云台需要明确的认证节点与实时角度来源。';
        return '';
    }
    Component.onCompleted:load()
    OperatorText {Layout.fillWidth:true;text:'移动相机定位 · 参数与接入';size:16;wrapMode:Text.Wrap}
    OperatorText {
        Layout.fillWidth:true;color:Theme.muted;wrapMode:Text.Wrap
        text:'从整机框底部、相机参数和同期本车位姿估计地面交点。虚线范围是参数误差估计，不能作为测量精度；平台、遮挡及镜头转动会影响结果。未配置时仍保留并共享图像框。'
    }
    CheckBox {id:enableProjection;text:'启用移动相机地面估计';palette.windowText:Theme.text;checked:initial.enabled===true;enabled:root.editable}
    OperatorConfigComboBox {id:frame;Layout.fillWidth:true;model:['field.2026','field.2027'];currentIndex:initial.frame_id==='field.2027'?1:0;Accessible.name:'投影输出坐标系';enabled:root.editable}
    OperatorText {Layout.fillWidth:true;text:'现有RobotPosition属于field.2026；选择field.2027须接入同坐标系的授权位姿传感器，并与完整JSON和队友配置一致，不能仅改名称。';color:Theme.muted;wrapMode:Text.Wrap}
    OperatorConfigComboBox {
        id:yawDirection;Layout.fillWidth:true;model:['正北零度，顺时针为正','正北零度，逆时针为正']
        currentIndex:initial.pose_heading_clockwise===true?0:initial.pose_heading_clockwise===false?1:-1
        displayText:currentIndex<0?'请选择本车朝向角度正方向':currentText
        Accessible.name:'RobotPosition朝向角度方向';enabled:root.editable
    }
    Repeater {
        model:[{key:'calibration_id',label:'相机配置标识',hint:'例如camera-main-v1'},
            {key:'fx',label:'归一化水平焦距 fx / 图像宽',hint:'填写实际参数'},
            {key:'fy',label:'归一化垂直焦距 fy / 图像高',hint:'填写实际参数'},
            {key:'cx',label:'归一化光心 cx / 图像宽',hint:'常接近0.5，以标定为准'},
            {key:'cy',label:'归一化光心 cy / 图像高',hint:'常接近0.5，以标定为准'},
            {key:'camera_height_m',label:'相机到目标地面的高度（米）',hint:'需实际填写'},
            {key:'pitch_down_deg',label:'相机安装俯角（度，向下为正）',hint:'需实际填写'},
            {key:'camera_yaw_offset_deg',label:'相机相对车体水平偏角（度，顺时针为正）',hint:'例如0'},
            {key:'roll_clockwise_deg',label:'相机画面滚转角（度，顺时针为正）',hint:'例如0'}]
        ColumnLayout {
            required property var modelData
            Layout.fillWidth:true;spacing:3
            OperatorText {Layout.fillWidth:true;text:modelData.label;size:12;color:Theme.muted;wrapMode:Text.Wrap}
            OperatorConfigTextField {Layout.fillWidth:true;text:String(root.values[modelData.key]??'');placeholderText:modelData.hint;Accessible.name:modelData.label;enabled:root.editable;onTextEdited:root.put(modelData.key,text)}
        }
    }
    CheckBox {id:rigid;text:'相机固定在车体上，视角不会随云台变化';palette.windowText:Theme.text;checked:initial.rigid_camera_confirmed===true;enabled:root.editable}
    Repeater {
        model:[{key:'gimbal_node_id',label:'云台角度提供节点（认证白名单内）'},{key:'gimbal_source_id',label:'云台角度source_id'}]
        ColumnLayout {
            required property var modelData
            Layout.fillWidth:true;visible:!rigid.checked;spacing:3
            OperatorText {Layout.fillWidth:true;text:modelData.label;size:12;color:Theme.muted;wrapMode:Text.Wrap}
            OperatorConfigTextField {Layout.fillWidth:true;text:String(root.values[modelData.key]??'');Accessible.name:modelData.label;enabled:root.editable;onTextEdited:root.put(modelData.key,text)}
        }
    }
    CheckBox {id:acknowledged;text:'已核对相机安装与目标接地点的地面假设';palette.windowText:Theme.text;checked:initial.acknowledged===true;enabled:root.editable}
    CheckBox {id:imageConfirmed;text:'已核对内参、畸变与当前视频图像模型';palette.windowText:Theme.text;checked:initial.image_model_confirmed===true;enabled:root.editable}
    OperatorText {Layout.fillWidth:true;visible:root.formError.length>0;text:root.formError;color:Theme.warning;wrapMode:Text.Wrap}
    Flow {
        Layout.fillWidth:true;spacing:8
        OperatorButton {text:'从当前JSON读取';enabled:!!root.host;onClicked:root.load()}
        OperatorButton {
            objectName:'saveMobileCameraProjection';text:'保存本机相机配置';enabled:root.editable && root.formError.length===0 && !!root.host
            onClicked:{
                if(root.host.saveProjectionConfiguration(root.configurationFile,root.configuration(),root.modelFile)){
                    root.feedback='已保存本机副本。请点击上方「应用视觉 / 队内通信配置」后生效。';root.saved(root.host.configurationFile);
                } else root.feedback=root.host.status;
            }
        }
    }
    OperatorText {Layout.fillWidth:true;visible:feedback.length>0;text:feedback;color:Theme.muted;wrapMode:Text.Wrap}
    OperatorText {Layout.fillWidth:true;color:Theme.muted;wrapMode:Text.Wrap;text:root.host?.view?.vision?.projection?.status??'定位尚未运行；保存参数不会自动启用YOLO。'}
}

# Home Assistant 설정 가이드

이 문서는 Home Assistant에서 `vehicleconnect17671.distancecm` 커스텀 capability를 인식하고 사용하는 방법을 설명합니다.

## 1단계: SmartThings 통합 설정

1. Home Assistant에서 **설정** → **통합구성요소** → **SmartThings** 추가
2. SmartThings 디바이스를 스캔하고 연결
3. mmWave Presence 센서가 추가되는지 확인

## 2단계: 디바이스 속성 확인

커스텀 capability의 실제 attribute 이름을 확인하기 위해 다음 단계를 따르세요:

1. **개발자 도구** → **상태**로 이동
2. `binary_sensor.mmwave_presence_sensor` 또는 해당 디바이스 이름 검색
3. 디바이스를 클릭하여 **모든 속성(attributes)** 확인
4. `vehicleconnect17671_distancecm_distance` 또는 유사한 이름의 속성 찾기

또는 아래 디버그 센서를 추가하여 모든 속성을 확인할 수 있습니다:

```yaml
# configuration.yaml에 추가 (임시 - 디버깅용)
template:
  - sensor:
      - name: "mmWave Debug All Attributes"
        unique_id: "mmwave_debug"
        state: "{{ states.binary_sensor.YOUR_DEVICE_ID | to_json }}"
```

## 3단계: Template Sensor 설정

`configuration.yaml` 또는 `sensors.yaml`에 다음을 추가하세요:

```yaml
template:
  - sensor:
      - name: "mmWave Presence Distance"
        unique_id: "tuya_mmwave_presence_distance"
        state: >
          {% set attr = state_attr('binary_sensor.YOUR_DEVICE_ID', 'vehicleconnect17671_distancecm_distance') %}
          {% if attr is mapping %}
            {{ attr.value if attr.value is defined else attr }}
          {% else %}
            {{ attr }}
          {% endif %}
        unit_of_measurement: "cm"
        device_class: "distance"
        availability: "{{ states('binary_sensor.YOUR_DEVICE_ID') != 'unavailable' }}"
```

**주의**: `YOUR_DEVICE_ID`를 실제 디바이스 entity ID로 변경하세요.

## 4단계: 자동화에서 사용

Template sensor가 생성되면 자동화에서 일반 센서처럼 사용할 수 있습니다:

```yaml
automation:
  - alias: "Distance Alert"
    trigger:
      - platform: numeric_state
        entity_id: sensor.mmwave_presence_distance
        above: 500
    action:
      - service: notify.mobile_app_your_phone
        data:
          message: "mmWave 센서가 500cm 이상의 거리를 감지했습니다"
```

## 문제 해결

### 속성을 찾을 수 없는 경우

1. SmartThings 앱에서 디바이스가 정상적으로 작동하는지 확인
2. Home Assistant SmartThings 통합 로그 확인:
   - **설정** → **시스템** → **로그**
   - SmartThings 관련 에러 메시지 확인

3. SmartThings 디바이스를 다시 동기화:
   - **설정** → **통합구성요소** → **SmartThings** → **옵션** → **동기화**

### 값이 업데이트되지 않는 경우

1. Template sensor의 `availability` 조건 확인
2. SmartThings 디바이스의 상태가 `unavailable`이 아닌지 확인
3. Template sensor를 수동으로 새로고침 (HA 재시작)

## 대안: MQTT 사용

SmartThings Edge 드라이버가 MQTT를 지원한다면, MQTT 통합을 통해 직접 distance 값을 받을 수 있습니다. (현재 드라이버는 Zigbee 직접 연결이므로 이 방법은 적용되지 않습니다)

## 참고

- 표준 capability인 `motionSensor`와 `illuminanceMeasurement`는 Home Assistant에서 자동으로 인식됩니다
- 커스텀 capability는 template sensor를 통해 수동으로 매핑해야 합니다
- SmartThings 통합의 버전에 따라 attribute 이름이나 접근 방법이 다를 수 있습니다


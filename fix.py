import re

p1 = 'lib/exercise/glute bridge/metrics/glute_bridge_speed_control.dart'
text1 = open(p1, 'r', encoding='utf-8').read()
text1 = re.sub(r'[ \t]*voiceMessage:\s*\'Chậm lại\',[ \t]*\r?\n', '', text1)
open(p1, 'w', encoding='utf-8').write(text1)

p2 = 'lib/exercise/glute bridge/metrics/glute_bridge_knee_angle.dart'
text2 = open(p2, 'r', encoding='utf-8').read()
text2 = re.sub(r'[ \t]*voiceMessage:\s*\'Chỉnh góc gối\',[ \t]*\r?\n', '', text2)
open(p2, 'w', encoding='utf-8').write(text2)

p3 = 'lib/exercise/jumping jack/metrics/arm_extension_metric.dart'
text3 = open(p3, 'r', encoding='utf-8').read()
text3 = re.sub(r',\s*voiceMessage:\s*\'Đưa tay cao hơn\'', '', text3)
open(p3, 'w', encoding='utf-8').write(text3)

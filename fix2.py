import re
p1 = 'lib/exercise/glute bridge/metrics/glute_bridge_speed_control.dart'
text1 = open(p1, 'r', encoding='utf-8').read()
text1 = re.sub(r'voiceMessage:\s*\'Chậm lại\',\s*', '', text1)
open(p1, 'w', encoding='utf-8').write(text1)

p3 = 'lib/exercise/jumping jack/metrics/arm_extension_metric.dart'
text3 = open(p3, 'r', encoding='utf-8').read()
text3 = re.sub(r'\{String\? voiceMessage\}', '{}', text3)
text3 = re.sub(r'voiceMessage:\s*voiceMessage,', '', text3)
open(p3, 'w', encoding='utf-8').write(text3)

import re
p3 = 'lib/exercise/jumping jack/metrics/arm_extension_metric.dart'
text3 = open(p3, 'r', encoding='utf-8').read()
text3 = text3.replace('void _logFault(String phase, String message, {})', 'void _logFault(String phase, String message)')
text3 = re.sub(r'message: message,\s*affectsForm: true,', 'message: message,\\n        affectsForm: true,', text3)
open(p3, 'w', encoding='utf-8').write(text3)

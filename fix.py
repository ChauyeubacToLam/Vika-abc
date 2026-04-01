import re
with open(r'd:/vinafit/Vinafit-mobile/lib/exercise/push up/metrics/trunk_alignment_metric.dart', 'r', encoding='utf-8') as f:
    text = f.read()

text = text.replace(\"_logFault(phase, 'Hông quá cao');\", \"_logFault(phase, 'Hông quá cao', voiceMessage: 'Hạ hông xuống');\")
text = text.replace(\"_logFault(phase, 'Hông hơi cao');\", \"_logFault(phase, 'Hông hơi cao', voiceMessage: 'Hạ hông xuống');\")

with open(r'd:/vinafit/Vinafit-mobile/lib/exercise/push up/metrics/trunk_alignment_metric.dart', 'w', encoding='utf-8') as f:
    f.write(text)

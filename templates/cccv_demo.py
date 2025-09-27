import os

import vapoursynth as vs
from vapoursynth import core

from cccv import AutoModel, ConfigType, SRBaseModel
import mvsfunc as mvf

model: SRBaseModel = AutoModel.from_pretrained(
    ConfigType.RealESRGAN_AnimeJaNai_HD_V3_Compact_2x, tile=None
)

if os.getenv("FINALRIP_SOURCE"):
    clip = core.bs.VideoSource(source=os.getenv("FINALRIP_SOURCE"))
else:
    clip = core.bs.VideoSource(source="s.mkv")

clip = mvf.ToRGB(clip, depth=16, sample=vs.FLOAT)
clip = model.inference_video(clip)
clip = mvf.ToYUV(clip, matrix="709", css="420", depth=10)
clip.set_output()

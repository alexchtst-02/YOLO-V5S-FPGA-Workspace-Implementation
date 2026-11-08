# FPGA Output Error Comparison

FPGA Q6.10 outputs were compared with **Conv + BatchNorm fused YOLOv5s v7.0 FP32** on **15 COCO val2017 images**. All 15 captures were included, covering **32,130,000 valid output values** across the three detection heads, before sigmoid and NMS.

**Error = FPGA − FP32.** The combined results were:

- **MAE:** 0.025099
- **RMSE:** 0.039982
- **Maximum absolute error:** 1.525083
- **Mean signed error:** -0.000173

![FPGA output error summary](error_summary.png)

Average absolute error was similar across the three heads: **0.024494–0.026856**. `det2` had the highest MAE and RMSE, while `det0` contained the largest individual error. The near-zero combined signed mean indicates little net offset; individual deviations remain visible in the MAE and RMSE.

The maximum error was substantially larger than the average error, showing that some output values differed considerably more than the overall mean suggests.

![Absolute output error distributions](error_histograms.png)

Per-image MAE ranged from **0.018650** for `000000027620.jpg` to **0.039140** for `000000107554.jpg`. The largest individual deviation, **1.525083**, also occurred in `000000107554.jpg`.

![Numerical error for all 15 evaluated images](error_per_image.png)

These values are raw-logit differences, not detection-accuracy percentages. They describe the combined numerical difference between this fixed-point implementation and FP32 on the evaluated sample. Detection mAP requires a separate evaluation against ground-truth annotations.

<details>
<summary>Spatial error results for all 15 images</summary>

![Spatial output error — 000000021167.jpg](error_heatmap_000000021167.jpg_0bcc98de.png)

![Spatial output error — 000000025228.jpg](error_heatmap_000000025228.jpg_f13c274c.png)

![Spatial output error — 000000027620.jpg](error_heatmap_000000027620.jpg_96fab208.png)

![Spatial output error — 000000083531.jpg](error_heatmap_000000083531.jpg_8b2752aa.png)

![Spatial output error — 000000089648.jpg](error_heatmap_000000089648.jpg_f58c3f20.png)

![Spatial output error — 000000098520.jpg](error_heatmap_000000098520.jpg_15bff129.png)

![Spatial output error — 000000107554.jpg](error_heatmap_000000107554.jpg_4c8a4c8d.png)

![Spatial output error — 000000134322.jpg](error_heatmap_000000134322.jpg_5bd3837f.png)

![Spatial output error — 000000205647.jpg](error_heatmap_000000205647.jpg_ae051fa9.png)

![Spatial output error — 000000210299.jpg](error_heatmap_000000210299.jpg_3a904647.png)

![Spatial output error — 000000230166.jpg](error_heatmap_000000230166.jpg_b546177f.png)

![Spatial output error — 000000260657.jpg](error_heatmap_000000260657.jpg_38e47e35.png)

![Spatial output error — 000000400573.jpg](error_heatmap_000000400573.jpg_5e294c63.png)

![Spatial output error — 000000517687.jpg](error_heatmap_000000517687.jpg_2805d394.png)

![Spatial output error — 000000563470.jpg](error_heatmap_000000563470.jpg_fac084a0.png)

</details>

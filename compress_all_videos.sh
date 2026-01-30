#!/bin/bash
# 压缩所有超过5MB或超过1080p的视频

VIDEO_DIR="/Users/nemo.liu/code/robotransfer_homepage/static/videos"
MAX_SIZE_MB=5
MAX_HEIGHT=1080

echo "开始压缩视频..."
echo "目录: $VIDEO_DIR"
echo "大小限制: ${MAX_SIZE_MB}MB"
echo "分辨率限制: 720p - ${MAX_HEIGHT}p"
echo ""

find "$VIDEO_DIR" -name "*.mp4" -type f | while read video; do
    filename=$(basename "$video")
    size_mb=$(du -m "$video" | cut -f1)
    
    # 获取分辨率
    resolution=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 "$video" 2>/dev/null)
    if [ -z "$resolution" ]; then
        echo "⚠ $filename: ${size_mb}MB (无法读取分辨率，跳过)"
        continue
    fi
    
    width=$(echo $resolution | cut -d',' -f1)
    height=$(echo $resolution | cut -d',' -f2)
    
    need_compress=false
    reason=""
    
    if [ "$size_mb" -gt "$MAX_SIZE_MB" ]; then
        need_compress=true
        reason="大小 ${size_mb}MB > ${MAX_SIZE_MB}MB"
    fi
    
    if [ "$height" -gt "$MAX_HEIGHT" ]; then
        need_compress=true
        if [ -n "$reason" ]; then
            reason="$reason, "
        fi
        reason="${reason}分辨率 ${height}p > ${MAX_HEIGHT}p"
    fi
    
    if [ "$need_compress" = true ]; then
        echo "⚠ $filename: ${size_mb}MB, ${width}x${height}"
        echo "  原因: $reason"
        
        # 计算目标分辨率
        target_width=$width
        target_height=$height
        if [ "$height" -gt "$MAX_HEIGHT" ]; then
            scale=$(echo "scale=2; $MAX_HEIGHT / $height" | bc)
            target_height=$MAX_HEIGHT
            target_width=$(echo "$width * $scale / 1" | bc)
            # 确保是偶数
            target_width=$((target_width - target_width % 2))
        fi
        
        # 计算码率（简化：根据目标大小）
        target_bitrate=2000
        if [ "$target_height" -ge 1080 ]; then
            target_bitrate=3000
        elif [ "$target_height" -ge 720 ]; then
            target_bitrate=2000
        else
            target_bitrate=1500
        fi
        
        dir=$(dirname "$video")
        base=$(basename "$video" .mp4)
        compressed="${dir}/${base}_compressed.mp4"
        backup="${dir}/${base}_original.mp4"
        
        echo "  压缩中... (码率: ${target_bitrate}kbps, 分辨率: ${target_width}x${target_height})"
        
        # 构建ffmpeg命令
        if [ "$target_width" != "$width" ] || [ "$target_height" != "$height" ]; then
            ffmpeg -i "$video" \
                -vf "scale=${target_width}:${target_height}:force_original_aspect_ratio=decrease" \
                -c:v libx264 -preset medium \
                -b:v ${target_bitrate}k -maxrate ${target_bitrate}k -bufsize $((target_bitrate * 2))k \
                -c:a aac -b:a 128k \
                -movflags +faststart \
                -y "$compressed" 2>/dev/null
        else
            ffmpeg -i "$video" \
                -c:v libx264 -preset medium \
                -b:v ${target_bitrate}k -maxrate ${target_bitrate}k -bufsize $((target_bitrate * 2))k \
                -c:a aac -b:a 128k \
                -movflags +faststart \
                -y "$compressed" 2>/dev/null
        fi
        
        if [ $? -eq 0 ] && [ -f "$compressed" ]; then
            new_size=$(du -m "$compressed" | cut -f1)
            reduction=$(echo "scale=1; (1 - $new_size / $size_mb) * 100" | bc)
            echo "  ✓ 完成: ${new_size}MB (减少 ${reduction}%)"
            
            mv "$video" "$backup"
            mv "$compressed" "$video"
            echo "  原文件备份为: ${base}_original.mp4"
        else
            echo "  ✗ 压缩失败"
            rm -f "$compressed"
        fi
        echo ""
    else
        echo "✓ $filename: ${size_mb}MB, ${width}x${height} (无需压缩)"
    fi
done

echo "完成！"

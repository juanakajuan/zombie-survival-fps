#!/usr/bin/env bash
# Records sound effects from the default microphone into audio/sfx/<name>.wav.
# For each sound, it plays the current sound, records until you press Enter, cuts the silence at both
# ends, and sets the peak to the level of the other sounds. You keep the take or record it again.
# The .tres events point at these paths, so a kept take plays in the game after the next import.
# Usage: tools/record_sfx.sh [name ...]          (no name: every sound in audio/sfx/)
#        tools/record_sfx.sh --process in out.wav (process a take that you recorded in another app)
set -euo pipefail
cd "$(dirname "$0")/.."

RATE=44100
# Peak of 0.9, the same level as every other file in audio/sfx/.
PEAK_DB=-0.92
# A level below this at the start or the end of a take is silence and is cut.
SILENCE_DB=-40
# A raw take with a peak below this is too quiet: normalizing it also makes the room noise loud.
QUIET_DB=-30

declare -A HINT=(
	[gunshot]="One loud, short shot. A hard 'K' or 'P' into the mic, then a 'boom'."
	[dry_click]="A very short, dry click. A tongue click."
	[reload]="Three clicks in about 1 s: magazine out, magazine in, slide."
	[hit]="A short, bright 'tick'. The player hears it on each hit."
	[kill]="A short 'tick-tick' that sounds better than the hit."
	[zombie_groan_1]="A slow, low groan, about 1 s."
	[zombie_groan_2]="A shorter groan, a bit higher, about 0.8 s."
	[zombie_groan_3]="A long, very low groan, about 1.4 s."
	[zombie_attack]="A fast swing and a hit. A growl that ends hard."
	[zombie_death]="A groan that falls and stops, about 1 s."
	[player_hurt]="A short grunt of pain."
	[round_start]="A rising call that says a new round starts, about 1.2 s."
	[break_start]="A falling call that says the round is done, about 1.2 s."
)

peak_db() {
	ffmpeg -nostdin -hide_banner -nostats -i "$1" -af volumedetect -f null - 2>&1 |
		sed -n 's/.*max_volume: \(-\?[0-9.]*\) dB.*/\1/p' || true
}

duration() {
	ffprobe -v error -show_entries format=duration -of csv=p=0 "$1"
}

# Cuts the silence at both ends, adds 5 ms fades against clicks, and writes 16-bit mono at the peak level.
process() {
	local raw="$1" out="$2" trimmed peak
	trimmed="$(mktemp --suffix=.wav)"
	local cut="silenceremove=start_periods=1:start_threshold=${SILENCE_DB}dB:start_silence=0.01"
	ffmpeg -nostdin -hide_banner -loglevel error -y -i "$raw" \
		-af "highpass=f=60,$cut,areverse,$cut,afade=t=in:d=0.005,areverse,afade=t=in:d=0.005" \
		-ac 1 -ar "$RATE" -c:a pcm_s16le "$trimmed" || true
	peak="$(peak_db "$trimmed")"
	if [[ -z "$peak" ]]; then
		rm -f "$trimmed"
		echo "The take is empty or all silence." >&2
		return 1
	fi
	ffmpeg -nostdin -hide_banner -loglevel error -y -i "$trimmed" \
		-af "volume=$(awk -v p="$PEAK_DB" -v m="$peak" 'BEGIN { print p - m }')dB" \
		-ac 1 -ar "$RATE" -c:a pcm_s16le "$out"
	rm -f "$trimmed"
}

if [[ "${1:-}" == "--process" ]]; then
	[[ $# -eq 3 ]] || { echo "Usage: $0 --process in out.wav" >&2; exit 2; }
	process "$2" "$3"
	exit
fi

names=("$@")
if [[ ${#names[@]} -eq 0 ]]; then
	for f in audio/sfx/*.wav; do names+=("$(basename "$f" .wav)"); done
fi
for name in "${names[@]}"; do
	[[ -f "audio/sfx/$name.wav" ]] || { echo "No sound audio/sfx/$name.wav" >&2; exit 2; }
done

raw="$(mktemp --suffix=.wav)"
take="$(mktemp --suffix=.wav)"
trap 'rm -f "$raw" "$take"' EXIT

record() {
	pw-record --rate 48000 --channels 1 --format s16 "$raw" &
	local pid=$!
	read -rp "Recording. Press Enter to stop. "
	kill -TERM "$pid"
	wait "$pid" || true
}

kept=0
for i in "${!names[@]}"; do
	name="${names[$i]}"
	file="audio/sfx/$name.wav"
	echo
	echo "== $name ($((i + 1))/${#names[@]}), now $(printf '%.2f' "$(duration "$file")") s =="
	echo "${HINT[$name]:-}"
	key=""
	while true; do
		if [[ "$key" != "again" ]]; then
			read -rp "Enter: record. o: play the current sound. s: skip. q: quit. " key
			case "$key" in
				o) pw-play "$file"; continue ;;
				s) break ;;
				q) echo "Kept $kept sounds."; exit ;;
				"") ;;
				*) continue ;;
			esac
		fi
		key=""
		record
		raw_peak="$(peak_db "$raw")"
		if [[ -n "$raw_peak" ]] && awk -v p="$raw_peak" -v q="$QUIET_DB" 'BEGIN { exit !(p < q) }'; then
			echo "The take is quiet (peak $raw_peak dB). Move closer to the mic or increase the input gain."
		fi
		process "$raw" "$take" || continue
		echo "Take: $(printf '%.2f' "$(duration "$take")") s."
		pw-play "$take"
		while true; do
			read -rp "k: keep. p: play again. o: play the current sound. Enter: record again. " key
			case "$key" in
				p) pw-play "$take" ;;
				o) pw-play "$file" ;;
				k) break ;;
				"") key="again"; break ;;
			esac
		done
		if [[ "$key" == "k" ]]; then
			cp "$take" "$file"
			kept=$((kept + 1))
			echo "Saved $file."
			break
		fi
	done
done
echo
echo "Kept $kept sounds. Run tools/check.sh to import them, then play the game to hear them."

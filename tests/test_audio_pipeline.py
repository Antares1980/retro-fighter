import os
import struct
import unittest

class OggVorbisInfo:
    def __init__(self, channels: int, samplerate: int, duration: float, format: str = "OGG", subtype: str = "VORBIS"):
        self.channels = channels
        self.samplerate = samplerate
        self.duration = duration
        self.format = format
        self.subtype = subtype


def parse_ogg_vorbis(filepath: str) -> OggVorbisInfo:
    with open(filepath, "rb") as f:
        data = f.read()

    if not data.startswith(b"OggS"):
        raise ValueError("Not an OGG container")

    # The first page contains the Vorbis identification header packet
    num_segments = data[26]
    segment_table = data[27 : 27 + num_segments]
    header_size = 27 + num_segments

    first_pkt_len = 0
    for seg in segment_table:
        first_pkt_len += seg
        if seg < 255:
            break

    first_packet = data[header_size : header_size + first_pkt_len]

    if len(first_packet) < 30 or first_packet[0] != 1 or first_packet[1:7] != b"vorbis":
        raise ValueError("Not a Vorbis audio stream")

    channels = first_packet[11]
    samplerate = struct.unpack("<I", first_packet[12:16])[0]

    last_pos = data.rfind(b"OggS")
    if last_pos == -1:
        raise ValueError("No OggS pages found")
    last_granule = struct.unpack("<q", data[last_pos + 6 : last_pos + 14])[0]
    duration = last_granule / samplerate

    return OggVorbisInfo(channels=channels, samplerate=samplerate, duration=duration)


class TestAudioPipeline(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        cls.doc_path = os.path.join(cls.base_dir, "docs", "standards", "audio-pipeline.md")
        cls.audio_path = os.path.join(cls.base_dir, "audio", "music", "stage_theme.ogg")
        cls.import_path = os.path.join(cls.base_dir, "audio", "music", "stage_theme.ogg.import")
        cls.bus_layout_path = os.path.join(cls.base_dir, "default_bus_layout.tres")
        cls.main_scene_path = os.path.join(cls.base_dir, "scenes", "Main.tscn")

    def test_doc_exists_and_standards(self):
        self.assertTrue(os.path.isfile(self.doc_path), "docs/standards/audio-pipeline.md must exist")
        with open(self.doc_path, "r", encoding="utf-8") as f:
            content = f.read()

        # 4-phase workflow
        self.assertIn("140 BPM", content)
        self.assertIn("Yamaha FM", content)
        self.assertIn("CPS-1", content)
        self.assertIn("Audacity", content)
        self.assertIn("zero-crossing", content.lower())
        self.assertIn("loop = true", content)
        self.assertIn("loop_offset = 6.4", content)
        self.assertIn("default_bus_layout.tres", content)

        # Mermaid flowchart with specific quoted label
        self.assertIn("```mermaid", content)
        self.assertIn("<br/>", content)
        self.assertIn('-->|"Match State: ROUND_OVER (Any Reason)"|', content)

        # Non-normative guidance
        self.assertIn("non-normative", content.lower())
        self.assertIn("Suno", content)
        self.assertIn("Udio", content)
        self.assertIn("BeepBox", content)

    def test_audio_asset_properties(self):
        self.assertTrue(os.path.isfile(self.audio_path), "audio/music/stage_theme.ogg must exist")
        file_size = os.path.getsize(self.audio_path)
        # Must be < 2.5 MB (2,621,440 bytes)
        self.assertLess(file_size, 2.5 * 1024 * 1024, "Audio file must be < 2.5 MB")

        # Verify Vorbis audio properties
        info = parse_ogg_vorbis(self.audio_path)
        self.assertEqual(info.channels, 2, "Audio must be stereo (2 channels)")
        self.assertEqual(info.samplerate, 44100, "Audio sample rate must be 44.1 kHz")
        self.assertEqual(info.format, "OGG", "Container format must be OGG")
        self.assertEqual(info.subtype, "VORBIS", "Subtype must be VORBIS")
        self.assertGreater(info.duration, 6.4, "Audio duration must exceed loop offset of 6.4s")

    def test_audio_import_metadata(self):
        self.assertTrue(os.path.isfile(self.import_path), "audio/music/stage_theme.ogg.import must exist")
        with open(self.import_path, "r", encoding="utf-8") as f:
            content = f.read()

        self.assertIn("[params]", content)
        self.assertRegex(content, r'loop\s*=\s*true')
        self.assertRegex(content, r'loop_offset\s*=\s*6\.4')

    def test_default_bus_layout(self):
        self.assertTrue(os.path.isfile(self.bus_layout_path), "default_bus_layout.tres must exist")
        with open(self.bus_layout_path, "r", encoding="utf-8") as f:
            content = f.read()

        self.assertIn('type="AudioBusLayout"', content)
        self.assertRegex(content, r'bus/0/name\s*=\s*&"Master"')
        self.assertRegex(content, r'bus/1/name\s*=\s*&"Music"')
        self.assertRegex(content, r'bus/1/send\s*=\s*&"Master"')
        self.assertRegex(content, r'bus/2/name\s*=\s*&"SFX"')
        self.assertRegex(content, r'bus/2/send\s*=\s*&"Master"')

    def test_main_scene_bgm_player(self):
        self.assertTrue(os.path.isfile(self.main_scene_path), "scenes/Main.tscn must exist")
        with open(self.main_scene_path, "r", encoding="utf-8") as f:
            content = f.read()

        # BGMPlayer node exists with AudioStreamPlayer type
        self.assertIn('node name="BGMPlayer" type="AudioStreamPlayer" parent="."', content)
        self.assertTrue('res://audio/music/retro-fighter.ogg' in content or 'res://audio/music/stage_theme.ogg' in content)
        self.assertIn('bus = &"Music"', content)
        self.assertIn('autoplay = false', content)

    def test_retro_fighter_audio_asset_properties(self):
        retro_audio_path = os.path.join(self.base_dir, "audio", "music", "retro-fighter.ogg")
        self.assertTrue(os.path.isfile(retro_audio_path), "audio/music/retro-fighter.ogg must exist")
        info = parse_ogg_vorbis(retro_audio_path)
        self.assertEqual(info.channels, 2, "retro-fighter.ogg must be stereo (2 channels)")
        self.assertEqual(info.samplerate, 44100, "retro-fighter.ogg sample rate must be 44.1 kHz")
        self.assertEqual(info.format, "OGG")
        self.assertEqual(info.subtype, "VORBIS")
        self.assertAlmostEqual(info.duration, 170.66, delta=0.5)

    def test_retro_fighter_import_metadata(self):
        retro_import_path = os.path.join(self.base_dir, "audio", "music", "retro-fighter.ogg.import")
        self.assertTrue(os.path.isfile(retro_import_path), "audio/music/retro-fighter.ogg.import must exist")
        with open(retro_import_path, "r", encoding="utf-8") as f:
            content = f.read()
        self.assertIn("[params]", content)
        self.assertRegex(content, r'loop\s*=\s*true')
        self.assertRegex(content, r'loop_offset\s*=\s*0(\.0)?')

if __name__ == "__main__":
    unittest.main()

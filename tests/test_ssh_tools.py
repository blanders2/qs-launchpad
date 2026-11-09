"""Tests for bin/ssh-tools. Run: python3 -m unittest discover -s tests"""
import importlib.machinery
import importlib.util
import json
import os
import subprocess
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
TOOL = os.path.join(HERE, "..", "bin", "ssh-tools")
loader = importlib.machinery.SourceFileLoader("ssh_tools", TOOL)
spec = importlib.util.spec_from_loader("ssh_tools", loader)
st = importlib.util.module_from_spec(spec)
loader.exec_module(st)

KEY = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBn8z0m0dummydummydummydummydummydummydummy user@test"
KEY2 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOtherOtherOtherOtherOtherOtherOtherOther other@test"


def tunnel(**over):
    return {"id": "web", "name": "Web", "target": "user@myhost", "direction": "local", "bind": "127.0.0.1",
            "listen_port": 8080, "dest_host": "localhost", "dest_port": 80, **over}


class ConfigTest(unittest.TestCase):
    def test_aliases_skip_patterns_and_follow_include(self):
        with tempfile.TemporaryDirectory() as d:
            inc = os.path.join(d, "more.conf")
            with open(inc, "w") as f:
                f.write("Host extra\n  HostName 10.0.0.9\n")
            main = os.path.join(d, "config")
            with open(main, "w") as f:
                f.write(f"Include {inc}\n# Host commented\nHost win11 pi\n  User x\nHost *.lan !bad\nHost  spark  # trailing\n")
            self.assertEqual(st.config_aliases(main), ["extra", "win11", "pi", "spark"])

    def test_include_loop_terminates(self):
        with tempfile.TemporaryDirectory() as d:
            main = os.path.join(d, "config")
            with open(main, "w") as f:
                f.write(f"Include {main}\nHost a\n")
            self.assertEqual(st.config_aliases(main), ["a"])


class TargetTest(unittest.TestCase):
    def test_targets(self):
        for ok in ("myhost", "user@myhost", "my-host-1.local", "u@10.0.0.1", "[::1]"):
            self.assertEqual(st.valid_target(ok), ok)
        for bad in ("-oProxyCommand=x", "a b", "a;b", "", "a@-b c"):
            with self.assertRaises(st.Fail):
                st.valid_target(bad)


class KeyTest(unittest.TestCase):
    def test_pubkey_ok(self):
        self.assertEqual(st.clean_pubkey("  " + KEY + "\n"), KEY)

    def test_private_key_refused(self):
        with self.assertRaises(st.Fail):
            st.clean_pubkey("-----BEGIN OPENSSH PRIVATE KEY-----\nabc\n-----END OPENSSH PRIVATE KEY-----")

    def test_key_names(self):
        st.valid_key_name("id_work")
        for bad in ("-x", ".hidden", "a/b", "x" * 65):
            with self.assertRaises(st.Fail):
                st.valid_key_name(bad)

    def test_install_script_adds_then_skips(self):
        with tempfile.TemporaryDirectory() as home:
            env = {**os.environ, "HOME": home}
            run = lambda keys: subprocess.run(["sh", "-c", st.POSIX_INSTALL], input="\n".join(keys) + "\n",
                                              capture_output=True, text=True, env=env, check=True).stdout.split("\n")
            self.assertEqual(run([KEY])[:1], ["ADD " + KEY])
            self.assertEqual(run([KEY, KEY2])[:2], ["SKIP " + KEY, "ADD " + KEY2])
            path = os.path.join(home, ".ssh", "authorized_keys")
            with open(path) as f:
                self.assertEqual(f.read(), KEY + "\n" + KEY2 + "\n")
            self.assertEqual(oct(os.stat(path).st_mode & 0o777), "0o600")

    def test_list_keys_script_reads_only_pub(self):
        with tempfile.TemporaryDirectory() as home:
            os.makedirs(os.path.join(home, ".ssh"))
            for name, text in (("id_a.pub", KEY), ("id_a", "PRIVATE"), ("id_b.pub", KEY2)):
                with open(os.path.join(home, ".ssh", name), "w") as f:
                    f.write(text + "\n")
            out = subprocess.run(["sh", "-c", st.POSIX_LIST_KEYS], capture_output=True, text=True,
                                 env={**os.environ, "HOME": home}, check=True).stdout
            self.assertEqual(out.splitlines(), ["id_a.pub\t1\t" + KEY, "id_b.pub\t0\t" + KEY2])


class TunnelTest(unittest.TestCase):
    def test_validate_and_argv(self):
        t = st.validate_tunnel(tunnel(port="2222"))
        self.assertEqual(t["port"], 2222)
        self.assertEqual(st.tunnel_argv(t), ["ssh", "-N", "-o", "BatchMode=yes", "-o", "ExitOnForwardFailure=yes",
                                             "-o", "ServerAliveInterval=30", "-p", "2222", "-L",
                                             "127.0.0.1:8080:localhost:80", "--", "user@myhost"])
        r = st.validate_tunnel(tunnel(direction="remote", bind="0.0.0.0"))
        self.assertIn("-R", st.tunnel_argv(r))

    def test_rejects(self):
        for over in ({"id": "Bad Id"}, {"bind": "1.2.3.4"}, {"direction": "up"}, {"listen_port": 0},
                     {"dest_port": "x"}, {"dest_host": "-oX"}, {"target": "-oProxyCommand=sh"}, {"name": "a\nb"}):
            with self.assertRaises(st.Fail, msg=over):
                st.validate_tunnel(tunnel(**over))

    def test_save_assigns_ids_and_replaces(self):
        with tempfile.TemporaryDirectory() as d:
            path = os.path.join(d, "tunnels.json")
            a = st.cmd_tunnel_save({"file": path, "spec": json.dumps({**tunnel(), "id": "", "name": "My Web"})})["tunnel"]
            b = st.cmd_tunnel_save({"file": path, "spec": json.dumps({**tunnel(), "id": "", "name": "My Web"})})["tunnel"]
            self.assertEqual((a["id"], b["id"]), ("my-web", "my-web-2"))
            st.cmd_tunnel_save({"file": path, "spec": json.dumps({**a, "listen_port": 9090})})
            saved = st.load_tunnels(path)
            self.assertEqual([(t["id"], t["listen_port"]) for t in saved], [("my-web", 9090), ("my-web-2", 8080)])

    def test_bad_saved_entries_are_dropped(self):
        with tempfile.TemporaryDirectory() as d:
            path = os.path.join(d, "tunnels.json")
            with open(path, "w") as f:
                json.dump({"tunnels": [tunnel(), tunnel(bind="9.9.9.9", id="x"), tunnel()]}, f)
            self.assertEqual([t["id"] for t in st.load_tunnels(path)], ["web"])


if __name__ == "__main__":
    unittest.main()

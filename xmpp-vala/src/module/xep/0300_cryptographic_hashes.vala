using GLib;
using Gee;

namespace Xmpp.Xep.CryptographicHashes {
    public const string NS_URI = "urn:xmpp:hashes:2";

    public enum HashCmp {
        Match,
        Mismatch,
        None,
    }

    public class Hash {
        public string algo;
        // hash encoded in Base64
        public string val;

        public static string hash_name(ChecksumType type) {
            switch(type) {
                case ChecksumType.MD5:
                    return "md5";
                case ChecksumType.SHA1:
                    return "sha-1";
                case ChecksumType.SHA256:
                    return "sha-256";
                case ChecksumType.SHA384:
                    return "sha-384";
                case ChecksumType.SHA512:
                    return "sha-512";
            }
            return "(null)";
        }

        public static ChecksumType? supported_hash(string hash) {
            switch (hash) {
                case "sha-1":
                    return ChecksumType.SHA1;
                case "sha-256":
                    return ChecksumType.SHA256;
                case "sha-384":
                    return ChecksumType.SHA384;
                case "sha-512":
                    return ChecksumType.SHA512;
            }
            return null;
        }

        public Hash.from_data(GLib.ChecksumType type, uint8[] data) {
            GLib.Checksum checksum = new GLib.Checksum(type);
            checksum.update(data, data.length);
            // 64 * 8 = 512 (sha-512 is the longest hash variant)
            uint8[] digest = new uint8[64];
            size_t length = digest.length;
            checksum.get_digest(digest, ref length);
            this.algo = hash_name(type);
            this.val = GLib.Base64.encode(digest[0:length]);
        }

        public HashCmp compare(Hash other) {
            if (this.algo != other.algo) {
                return HashCmp.None;
            }
            if (this.val == other.val) {
                return HashCmp.Match;
            } else {
                return HashCmp.Mismatch;
            }
        }

        public StanzaNode to_stanza_node() {
            return new StanzaNode.build("hash", NS_URI).add_self_xmlns()
                    .put_attribute("algo", this.algo)
                    .put_node(new StanzaNode.text(this.val));
        }

        public Hash.from_stanza_node(StanzaNode node) {
            this.algo = node.get_attribute("algo");
            this.val = node.get_string_content();
        }
    }

    public class Hashes {
        public Gee.List<Hash> hashes = new ArrayList<Hash>();

        public Gee.List<ChecksumType> supported_hashes() {
            Gee.List<ChecksumType> supported = new ArrayList<ChecksumType>();
            foreach (Hash hash in this.hashes) {
                ChecksumType? hash_type = Hash.supported_hash(hash.algo);
                if (hash_type != null) {
                    supported.add(hash_type);
                }
            }
            return supported;
        }

        public Hashes.from_data(Gee.List<ChecksumType> types, uint8[] data) {
            foreach (ChecksumType type in types) {
                this.hashes.add(new Hash.from_data(type, data));
            }
        }

        public HashCmp compare(Hashes other) {
            HashCmp cmp = HashCmp.None;
            foreach (Hash this_hash in this.hashes) {
                foreach (Hash other_hash in other.hashes) {
                    switch (this_hash.compare(other_hash)) {
                        case HashCmp.Mismatch:
                            return HashCmp.Mismatch;
                        case HashCmp.Match:
                            cmp = HashCmp.Match;
                            break;
                        case HashCmp.None:
                            continue;
                    }
                }
            }
            return cmp;
        }

        public Gee.List<StanzaNode> to_stanza_nodes() {
            Gee.List<StanzaNode> nodes = new ArrayList<StanzaNode>();
            foreach (Hash hash in this.hashes) {
                nodes.add(hash.to_stanza_node());
            }
            return nodes;
        }

        public Hashes.from_stanza_subnodes(StanzaNode node) {
            Gee.List<StanzaNode> subnodes = node.get_subnodes("hash", NS_URI);
            this.hashes = new ArrayList<Hash>();
            foreach (StanzaNode subnode in subnodes) {
                this.hashes.add(new Hash.from_stanza_node(subnode));
            }
        }
    }
}
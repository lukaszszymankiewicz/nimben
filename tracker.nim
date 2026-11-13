- Parse the .torrent File (Bencoding)

- What it is: Torrent files are encoded using Bencode (supporting strings, integers, lists, and dictionaries).

- What to extract:
Read the announce URL (tracker address), 
the piece length,
the raw pieces (concatenated SHA-1 hashes), and the info dictionary.

• Calculate the Info Hash: Compute the SHA-1 hash of the bencoded info dictionary.
This 20-byte info_hash is the unique fingerprint

you use to identify the torrent to trackers and peers.


set the GET request to the tracker, 

Now that we have the blueprint, we need the phonebook.
The tracker URL is specified in the .torrent file.
We send it an HTTP GET request with specific query parameters:
params:
 - [x] info_hash — The unique ID of this torrent ( cb40ac7b298f000b2c6ae08ebc319d88a0fc91e9)
 - [x] peer_id — Our unique identifier (a random 20-byte string) -qBXYZ0-<12 random bytes>
 -nT2137-123456789012

 - [x] port — Where other peers can reach us (49152)
 - [x] left — How many bytes we still need (initially, the full file size)
 - [x] compact=1 — “Please send the peer list in compact binary format”

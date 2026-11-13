import util
import parser

proc debugTorrentFile() =
    var raw: seq[byte] = util.readBinaryDataFromFile()
    var tree: Node = parser.createNodeTreeFromTorrentFile(raw)

    parser.printNodeTreeForHumans(tree)
    stdout.write "\n\n"
    parser.printNodeForHumans(tree)
    stdout.write "\n\n"
    var sha: string = parser.getInfoNodeSHAHash(tree)
    stdout.write sha

debugTorrentFile()

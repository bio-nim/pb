# vim: sw=4 ts=4 sts=4 tw=0 et:
from sequtils import nil
from strutils import format
import deques
import hts
import os
import ./kmers

proc foo*() =
    echo "foo"
proc showRec(record: Record) =
    echo format("$# $# ($#) [$# .. $#] $#", record.tid, record.chrom, record.qname, record.start, record.stop,
        ($record.cigar).substr(0, 32))

iterator overlaps(b: hts.Bam): seq[Record] =
    var current: Record
    var current_stack_index: int
    var stack = deques.initDeque[Record](64)
    for r in b:
        let record = hts.copy(r) # because iterator stores record on the Bam struct
        stack.addLast(record)
        if stack.len() == 1:
            current_stack_index = 0
            current = record
        showRec(record)  # DEBUG
        if record.start >= current.stop:
            yield sequtils.toSeq(stack)  # YIELD

            # Switch current to next record.
            current_stack_index += 1
            current = stack[current_stack_index]
            for i in 0 .. current_stack_index - 2:
                let ri = stack.peekFirst()
                #echo " Pop?", ri.stop, "<=?", current.start
                if ri.stop <= current.start:
                    discard stack.popFirst()

        #var rseq: string
        #discard hts.sequence(record, rseq)
        #var kmers: pot_t = dna_to_kmers(rseq, klen)

proc readaln*(bfn: string; fasta: string) =
    const klen = 21
    var b: hts.Bam

    hts.open(b, bfn, index=true)
    # We do not really need the index, but it proves that the Bam is sorted.
    # Actually, we expect it to be sorted with @SO=coordinate, so maybe we
    # should verify that. TODO(CD).
    # Note that the sort is wrong for circular genomes; the secondary key is
    # the query, not the coordinate. So we will need to do something tricky
    # for circular references. TODO(CD).
    echo "[INFO] reading bam"
    for ovlps in overlaps(b):
        echo "len=", len(ovlps)
        echo " range=", ovlps[0].start, "..", ovlps[^1].stop
 #[

  # for each overlapping read
  # complement to remove kmers that are in the reference where the read maps.
  rseq = get_ref(reference, record.ref, record.start-20, record.end+20)
  var refkmers = dna_to_kmers(rseq, 21)
  complement(kmers, refkmers)

  # find all read that overlap current read

  # count shared kmers between all overlapping reads

  # build weighted graph were nodes are reads and the edges are overlaps, weights are the number of shared kmers between reads

  edge between two nodes:
  - read id1, read id2
  - weight
  node:
  - read id
  - read start
  - read end

  # run unknown algorithm

  - merger function between nodes
  - dynamic programming

  ouput:
  	   tuples:
   	   - phase block id [0,1,2 ... ]
	   - phase block start
	   - phase block end
   	   - phase [0,1]
   	   - vector of read ids
]#

proc main*(aln_fn: string, ref_fn: string) =
    echo "[INFO] input reference (fasta):", ref_fn, ", reads:", aln_fn
    if strutils.find(ref_fn, "fa") == -1:
        echo format("[WARN] Bad fasta filename? '$#'", ref_fn)
    var refx: hts.Fai
    assert hts.open(refx, ref_fn)
    assert refx.len() == 1
    let reference_dna = refx.get(refx[0])
    readaln(aln_fn, reference_dna)
    echo "bye"

when isMainModule:
    main()

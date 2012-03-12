package edu.stanford.smallgraphs;

import java.io.DataInput;
import java.io.DataOutput;
import java.io.IOException;

import org.apache.hadoop.io.Writable;

public class MatchingMessage implements Writable {

	private int msgId;
	private final Matches matches;
	private final MatchPath path;

	public MatchingMessage(int msgId, Matches match, MatchPath path) {
		this.msgId = msgId;
		this.matches = match;
		this.path = path;
	}

	public MatchingMessage(int msgId, Matches match) {
		this(msgId, match, null);
	}

	public MatchingMessage(int msgId, MatchPath path) {
		this(msgId, null, path);
	}

	public MatchingMessage(int msgId) {
		this(msgId, null, null);
	}

	public int getMessageId() {
		return msgId;
	}

	public Matches getMatches() {
		return matches;
	}

	public MatchPath getPath() {
		return path;
	}

	@Override
	public void readFields(DataInput in) throws IOException {
		msgId = in.readInt();
		matches.readFields(in);
		path.readFields(in);
	}

	@Override
	public void write(DataOutput out) throws IOException {
		out.writeInt(msgId);
		matches.write(out);
		path.write(out);
	}

}

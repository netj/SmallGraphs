package edu.stanford.smallgraphs;

import java.io.DataInput;
import java.io.DataOutput;
import java.io.IOException;

import org.apache.hadoop.io.Writable;

public class MatchingMessage implements Writable {

	private final int msgId;
	private final Match match;
	private final MatchPath path;

	public MatchingMessage(int msgId, Match match, MatchPath path) {
		this.msgId = msgId;
		this.match = match;
		this.path = path;
	}

	public MatchingMessage(int msgId, Match match) {
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

	public Match getMatch() {
		return match;
	}

	public MatchPath getPath() {
		return path;
	}

	@Override
	public void readFields(DataInput arg0) throws IOException {
		// TODO Auto-generated method stub

	}

	@Override
	public void write(DataOutput arg0) throws IOException {
		// TODO Auto-generated method stub

	}

}

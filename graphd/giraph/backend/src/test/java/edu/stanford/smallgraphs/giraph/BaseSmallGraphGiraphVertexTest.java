package edu.stanford.smallgraphs.giraph;

import java.util.Map;

import junit.framework.TestCase;

import org.apache.giraph.utils.InternalVertexRunner;
import org.apache.hadoop.io.LongWritable;

import com.google.common.collect.Maps;

public class BaseSmallGraphGiraphVertexTest extends TestCase {
	static class IdentityVertex extends BaseSmallGraphGiraphVertex {
		@Override
		protected void handleMessages(Iterable<MatchingMessage> iterable) {
			for (MatchingMessage msg : iterable) {
				int messageId = msg.getMessageId();
				switch (messageId) {
				case 0:
					if (getVertexValue().getType() == 1) {
						for (LongWritable neighbor : this) {
							sendMsg(neighbor, new MatchingMessage(1));
						}
					}
					break;

				case 1:
					emitMatches(new Matches(getVertexId()));
					break;

				default:
					break;
				}
			}
		}
	}

	public void testInputOutput() throws Exception {
		String[] graph = new String[] { "[1,[2,{},3,{}], {\"\":1}]",
				"[2,[3,{},4,{}], {}]", "[3,[4,{}], {\"\":1}]", "[4,[], {}]" };
		Map<String, String> params = Maps.newHashMap();
		Iterable<String> result = InternalVertexRunner.run(
				IdentityVertex.class, PropertyGraphJSONVertexInputFormat.class,
				FinalMatchesOutputFormat.class
				// PropertyGraphJSONVertexOutputFormat.class
				, params, graph);

		System.out.println(result);
	}
}

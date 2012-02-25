package edu.stanford.smallgraphs;

import java.io.IOException;
import java.util.Map;

import org.apache.giraph.graph.BasicVertex;
import org.apache.giraph.graph.BspUtils;
import org.apache.giraph.graph.VertexReader;
import org.apache.giraph.lib.TextVertexInputFormat;
import org.apache.hadoop.io.LongWritable;
import org.apache.hadoop.io.Text;
import org.apache.hadoop.mapreduce.InputSplit;
import org.apache.hadoop.mapreduce.RecordReader;
import org.apache.hadoop.mapreduce.TaskAttemptContext;
import org.json.JSONArray;
import org.json.JSONException;

import com.google.common.collect.Maps;

/**
 * VertexInputFormat that supports {@link BaseSmallGraphGiraphVertex}
 */
public class PropertyGraphJSONVertexInputFormat
		extends
		TextVertexInputFormat<LongWritable, VertexMatchingState, PropertyMap, MatchingMessage> {
	@Override
	public VertexReader<LongWritable, VertexMatchingState, PropertyMap, MatchingMessage> createVertexReader(
			InputSplit split, TaskAttemptContext context)
			throws IOException {
		return new PropertyGraphJSONVertexReader(
				textInputFormat.createRecordReader(split, context));
	}

	/**
	 * VertexReader that supports {@link BaseSmallGraphGiraphVertex}. In
	 * this case, the edge values are not used. The files should be in the
	 * following JSON format: JSONArray(<vertex id>, <vertex value>,
	 * JSONArray(JSONArray(<dest vertex id>, <edge value>), ...)) Here is an
	 * example with vertex id 1, vertex value 4.3, and two edges. First edge
	 * has a destination vertex 2, edge value 2.1. Second edge has a
	 * destination vertex 3, edge value 0.7. [1,4.3,[[2,2.1],[3,0.7]]]
	 */
	public static class PropertyGraphJSONVertexReader
			extends
			TextVertexReader<LongWritable, VertexMatchingState, PropertyMap, MatchingMessage> {

		/**
		 * Constructor with the line record reader.
		 * 
		 * @param lineRecordReader
		 *            Will read from this line.
		 */
		public PropertyGraphJSONVertexReader(
				RecordReader<LongWritable, Text> lineRecordReader) {
			super(lineRecordReader);
		}

		@Override
		public BasicVertex<LongWritable, VertexMatchingState, PropertyMap, MatchingMessage> getCurrentVertex()
				throws IOException, InterruptedException {
			BasicVertex<LongWritable, VertexMatchingState, PropertyMap, MatchingMessage> vertex = BspUtils
					.<LongWritable, VertexMatchingState, PropertyMap, MatchingMessage> createVertex(getContext()
							.getConfiguration());

			Text line = getRecordReader().getCurrentValue();
			try {
				JSONArray jsonVertex = new JSONArray(line.toString());
				LongWritable vertexId = new LongWritable(
						jsonVertex.getLong(0));
				VertexMatchingState vertexValue = new VertexMatchingState(
						jsonVertex.getJSONObject(1));
				Map<LongWritable, PropertyMap> edges = Maps.newHashMap();
				JSONArray jsonEdgeArray = jsonVertex.getJSONArray(2);
				for (int i = 0; i < jsonEdgeArray.length(); ++i) {
					JSONArray jsonEdge = jsonEdgeArray.getJSONArray(i);
					edges.put(new LongWritable(jsonEdge.getLong(0)),
							new PropertyMap(jsonEdge.getJSONObject(1)));
				}
				vertex.initialize(vertexId, vertexValue, edges, null);
			} catch (JSONException e) {
				throw new IllegalArgumentException(
						"next: Couldn't get vertex from line " + line, e);
			}
			return vertex;
		}

		@Override
		public boolean nextVertex() throws IOException,
				InterruptedException {
			return getRecordReader().nextKeyValue();
		}
	}
}
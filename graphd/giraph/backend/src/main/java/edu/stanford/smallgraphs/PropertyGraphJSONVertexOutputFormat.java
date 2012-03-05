package edu.stanford.smallgraphs;

import java.io.IOException;

import org.apache.giraph.graph.BasicVertex;
import org.apache.giraph.graph.VertexWriter;
import org.apache.giraph.lib.TextVertexOutputFormat;
import org.apache.hadoop.io.LongWritable;
import org.apache.hadoop.io.Text;
import org.apache.hadoop.mapreduce.RecordWriter;
import org.apache.hadoop.mapreduce.TaskAttemptContext;
import org.json.JSONArray;

/**
 * VertexOutputFormat that supports {@link BaseSmallGraphGiraphVertex}
 */
public class PropertyGraphJSONVertexOutputFormat extends
		TextVertexOutputFormat<LongWritable, VertexMatchingState, PropertyMap> {
	@Override
	public VertexWriter<LongWritable, VertexMatchingState, PropertyMap> createVertexWriter(
			TaskAttemptContext context) throws IOException,
			InterruptedException {
		RecordWriter<Text, Text> recordWriter = textOutputFormat
				.getRecordWriter(context);
		return new TextVertexWriter<LongWritable, VertexMatchingState, PropertyMap>(
				recordWriter) {
			@Override
			public void writeVertex(
					BasicVertex<LongWritable, VertexMatchingState, PropertyMap, ?> vertex)
					throws IOException, InterruptedException {
				// TODO output only those vertices with final matches
				JSONArray jsonVertex = new JSONArray();
				jsonVertex.put(vertex.getVertexId().get());
				jsonVertex.put(vertex.getVertexValue().asJSONObject());
				JSONArray jsonEdgeArray = new JSONArray();
				for (LongWritable targetVertexId : vertex) {
					JSONArray jsonEdge = new JSONArray();
					jsonEdge.put(targetVertexId.get());
					jsonEdge.put(vertex.getEdgeValue(targetVertexId)
							.asJSONObject());
					jsonEdgeArray.put(jsonEdge);
				}
				jsonVertex.put(jsonEdgeArray);
				getRecordWriter().write(new Text(jsonVertex.toString()), null);
			}
		};
	}
}
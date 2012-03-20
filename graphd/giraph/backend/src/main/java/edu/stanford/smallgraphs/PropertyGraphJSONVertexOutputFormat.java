package edu.stanford.smallgraphs;

import java.io.IOException;
import java.util.List;

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
				// TODO output only those vertices and edges that are marked 
				JSONArray jsonVertex = new JSONArray();
				jsonVertex.put(vertex.getVertexId().get());
				JSONArray jsonEdgeArray = new JSONArray();
				for (LongWritable targetVertexId : vertex) {
					jsonEdgeArray.put(targetVertexId.get());
					jsonEdgeArray.put(vertex.getEdgeValue(targetVertexId)
							.asJSONObject());
				}
				jsonVertex.put(jsonEdgeArray);
				jsonVertex.put(vertex.getVertexValue().asJSONObject());
				getRecordWriter().write(new Text(jsonVertex.toString()), null);
			}
		};
	}
}
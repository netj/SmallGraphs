package edu.stanford.smallgraphs;

import info.aduna.io.ByteArrayUtil;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.io.OutputStreamWriter;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Map.Entry;
import java.util.Set;

import org.apache.commons.cli.CommandLine;
import org.apache.commons.cli.GnuParser;
import org.apache.commons.cli.HelpFormatter;
import org.apache.commons.cli.Options;
import org.apache.commons.cli.ParseException;
import org.json.JSONException;
import org.json.JSONObject;
import org.json.JSONWriter;
import org.openrdf.model.Literal;
import org.openrdf.model.Resource;
import org.openrdf.model.Statement;
import org.openrdf.model.URI;
import org.openrdf.model.Value;
import org.openrdf.rio.RDFFormat;
import org.openrdf.rio.RDFHandlerException;
import org.openrdf.rio.RDFParseException;
import org.openrdf.rio.RDFParser;
import org.openrdf.rio.Rio;
import org.openrdf.rio.helpers.RDFHandlerBase;

import com.sleepycat.je.Cursor;
import com.sleepycat.je.CursorConfig;
import com.sleepycat.je.Database;
import com.sleepycat.je.DatabaseConfig;
import com.sleepycat.je.DatabaseEntry;
import com.sleepycat.je.Environment;
import com.sleepycat.je.EnvironmentConfig;
import com.sleepycat.je.LockMode;
import com.sleepycat.je.OperationStatus;

public class RDFGraphTransformer {

	private Database edgeListByVertex;
	private Database propertyMapByVertex;

	public RDFGraphTransformer(File outputDir) {
		// initialize BerkeleyDB
		EnvironmentConfig envConfig = new EnvironmentConfig();
		envConfig.setAllowCreate(true);
		Environment myDbEnvironment = new Environment(outputDir, envConfig);
		DatabaseConfig dbConfig = new DatabaseConfig();
		dbConfig.setAllowCreate(true);
		dbConfig.setDeferredWrite(true);
		dbConfig.setSortedDuplicates(true);
		edgeListByVertex = myDbEnvironment.openDatabase(null, "vertices",
				dbConfig);
		propertyMapByVertex = myDbEnvironment.openDatabase(null, "properties",
				dbConfig);
	}

	private long typePredicateId;

	public void setTypeEdgeId(long typePredicateId) {
		this.typePredicateId = typePredicateId;
	}

	DatabaseEntry vertexIdDBEntry = new DatabaseEntry(new byte[8]);
	DatabaseEntry edgeDBEntry = new DatabaseEntry(new byte[2 * 8]);

	protected void addEdge(URI sURI, URI pURI, URI oURI) {
		// long encoded URIs have form of: ":1234"
		long sId = Long.valueOf(sURI.stringValue().substring(1));
		long pId = Long.valueOf(pURI.stringValue().substring(1));
		long oId = Long.valueOf(oURI.stringValue().substring(1));
		// System.err.println("+ " + sId + "-" + pId + "->" + oId);
		ByteArrayUtil.putLong(sId, vertexIdDBEntry.getData(), 0);
		byte[] edgeData = edgeDBEntry.getData();
		ByteArrayUtil.putLong(pId, edgeData, 0);
		ByteArrayUtil.putLong(oId, edgeData, 8);
		edgeListByVertex.put(null, vertexIdDBEntry, edgeDBEntry);
	}

	DatabaseEntry propertyDBEntry = new DatabaseEntry();
	byte[] propertyIdBuffer = new byte[8];

	protected void addProperty(URI sURI, URI pURI, Literal oLiteral)
			throws IOException, JSONException {
		// long encoded URIs have form of: ":1234"
		long sId = Long.valueOf(sURI.stringValue().substring(1));
		long pId = Long.valueOf(pURI.stringValue().substring(1));
		// System.err.println("+ " + sId + "@" + pId);
		ByteArrayUtil.putLong(sId, vertexIdDBEntry.getData(), 0);
		ByteArrayOutputStream byteArrayOutputStream = new ByteArrayOutputStream();
		// write predicate Id
		ByteArrayUtil.putLong(pId, propertyIdBuffer, 0);
		byteArrayOutputStream.write(propertyIdBuffer);
		// then, the value in JSON
		byteArrayOutputStream.write(oLiteral.stringValue().getBytes());
		byteArrayOutputStream.close();
		byte[] byteArray = byteArrayOutputStream.toByteArray();
		// store it in the map
		propertyDBEntry.setData(byteArray);
		propertyMapByVertex.put(null, vertexIdDBEntry, propertyDBEntry);
	}

	public void loadNTriples(InputStream input) throws RDFParseException,
			RDFHandlerException, IOException, JSONException {
		// parse N-Triples input and collect them in the maps
		RDFParser parser = Rio.createParser(RDFFormat.NTRIPLES);
		parser.setRDFHandler(new RDFHandlerBase() {
			@Override
			public void handleStatement(Statement st)
					throws RDFHandlerException {
				Resource s = st.getSubject();
				URI p = st.getPredicate();
				Value o = st.getObject();
				if (s instanceof URI) {
					URI sURI = (URI) s;
					if (o instanceof URI) {
						// edges
						URI oURI = (URI) o;
						addEdge(sURI, p, oURI);
					} else if (o instanceof Literal) {
						// properties
						Literal oLiteral = (Literal) o;
						try {
							addProperty(sURI, p, oLiteral);
						} catch (IOException e) {
							e.printStackTrace();
						} catch (JSONException e) {
							e.printStackTrace();
						}
					}
				}
				// TODO what else?
			}
		});
		parser.parse(input, "");
	}

	public void writeVertexOrientedGraphInJSON(OutputStream output)
			throws JSONException, IOException {
		// from the maps, output vertex-grouped graph in multiple lines of JSON
		OutputStreamWriter outputStreamWriter = new OutputStreamWriter(output);
		CursorConfig cursorConfig = new CursorConfig();
		Cursor edgeCursor = edgeListByVertex.openCursor(null, cursorConfig);
		Cursor propertiesCursor = propertyMapByVertex.openCursor(null,
				cursorConfig);
		DatabaseEntry vertexEntry = new DatabaseEntry();
		DatabaseEntry edgeEntry = new DatabaseEntry();
		DatabaseEntry propertyEntry = new DatabaseEntry();
		OperationStatus status = edgeCursor.getFirst(vertexEntry, edgeEntry,
				LockMode.DEFAULT);
		while (status == OperationStatus.SUCCESS) {
			JSONWriter jsonWriter = new JSONWriter(outputStreamWriter);
			jsonWriter.array();
			{
				// source vertex id
				long sId = ByteArrayUtil.getLong(vertexEntry.getData(), 0);
				jsonWriter.value(sId);
				// edge list
				Long vertexTypeId = writeVertexEdgesInJSON(jsonWriter,
						edgeCursor, propertiesCursor, vertexEntry, edgeEntry,
						propertyEntry);
				// node properties
				writeVertexPropertiesInJSON(jsonWriter, propertiesCursor,
						vertexEntry, propertyEntry, vertexTypeId);
			}
			jsonWriter.endArray();
			outputStreamWriter.flush();
			output.write('\n');
			status = edgeCursor.getNextNoDup(vertexEntry, edgeEntry,
					LockMode.DEFAULT);
		}
	}

	private Long writeVertexEdgesInJSON(JSONWriter jsonWriter,
			Cursor edgeCursor, Cursor propertiesCursor,
			DatabaseEntry vertexEntry, DatabaseEntry edgeEntry,
			DatabaseEntry propertyEntry) throws JSONException {
		OperationStatus status;
		jsonWriter.array();
		Long vertexTypeId = null;
		do {
			byte[] edgeData = edgeEntry.getData();
			long pId = ByteArrayUtil.getLong(edgeData, 0);
			long oId = ByteArrayUtil.getLong(edgeData, 8);
			if (vertexTypeId == null && pId == typePredicateId) {
				// keep the oId as vertex type
				vertexTypeId = oId;
				// skip the type edge since it'll be done as property
			} else {
				// System.err.println("= " + sId + "-" + pId + "->" + oId);
				// target vertex id
				jsonWriter.value(oId);
				// edge properties
				jsonWriter.object();
				// type
				jsonWriter.key("");
				jsonWriter.value(pId);
				// TODO more edge properties
				jsonWriter.endObject();
			}
			status = edgeCursor.getNextDup(vertexEntry, edgeEntry,
					LockMode.DEFAULT);
		} while (status == OperationStatus.SUCCESS);
		jsonWriter.endArray();
		return vertexTypeId;
	}

	private void writeVertexPropertiesInJSON(JSONWriter jsonWriter,
			Cursor propertiesCursor, DatabaseEntry vertexEntry,
			DatabaseEntry propertyEntry, Long vertexTypeId)
			throws JSONException {
		jsonWriter.object();
		{
			if (vertexTypeId != null) {
				// vertex type
				jsonWriter.key("");
				jsonWriter.value(vertexTypeId.longValue());
			}
			OperationStatus status = propertiesCursor.getSearchKey(vertexEntry,
					propertyEntry, LockMode.DEFAULT);
			Long prevPropertyId = null;
			String prevPropertyValue = null;
			boolean hasMultipleProperties = false;
			while (status == OperationStatus.SUCCESS) {
				byte[] propertyIdValue = propertyEntry.getData();
				long propertyId = ByteArrayUtil.getLong(propertyIdValue, 0);
				if (prevPropertyId == null || propertyId != prevPropertyId) {
					// for a new property id, write the end of the array or
					// previous value and start a new key
					if (prevPropertyValue != null)
						jsonWriter.value(prevPropertyValue);
					if (hasMultipleProperties) {
						jsonWriter.endArray();
						hasMultipleProperties = false;
					}
					jsonWriter.key(Long.toString(propertyId));
					prevPropertyId = propertyId;
				} else {
					// put in an array if node has multiple values for the same
					// property
					if (!hasMultipleProperties) {
						jsonWriter.array();
						hasMultipleProperties = true;
					}
					jsonWriter.value(prevPropertyValue);
				}
				prevPropertyValue = new String(propertyIdValue, 8,
						propertyIdValue.length - 8);
				status = propertiesCursor.getNextDup(vertexEntry,
						propertyEntry, LockMode.DEFAULT);
			}
			if (prevPropertyValue != null) {
				// just make sure we write the last value and close the array
				jsonWriter.value(prevPropertyValue);
				if (hasMultipleProperties)
					jsonWriter.endArray();
			}
		}
		jsonWriter.endObject();
	}

	CursorConfig cursorConfig = new CursorConfig();

	public void deriveSchema(OutputStream output) throws JSONException,
			IOException {
		// from the maps, scan each vertex and its edges, properties to
		// construct a schema
		Set<Long> vertexTypes = new HashSet<Long>();
		Map<Long, Set<Long>> domainByEdge = new HashMap<Long, Set<Long>>();
		Map<Long, Set<Long>> rangeByEdge = new HashMap<Long, Set<Long>>();
		Map<Long, Set<Long>> propertiesByVertex = new HashMap<Long, Set<Long>>();
		Map<Long, String> dataTypeByProperty = new HashMap<Long, String>();
		Cursor edgeCursor = edgeListByVertex.openCursor(null, cursorConfig);
		Cursor propertiesCursor = propertyMapByVertex.openCursor(null,
				cursorConfig);
		typeLookupCursor = edgeListByVertex.openCursor(null, cursorConfig);
		DatabaseEntry vertexEntry = new DatabaseEntry();
		DatabaseEntry edgeEntry = new DatabaseEntry();
		DatabaseEntry propertyEntry = new DatabaseEntry();
		OperationStatus status = edgeCursor.getFirst(vertexEntry, edgeEntry,
				LockMode.DEFAULT);
		// for each vertex
		while (status == OperationStatus.SUCCESS) {
			long sId = ByteArrayUtil.getLong(vertexEntry.getData(), 0);
			Long sTypeId = lookupType(sId);
			if (sTypeId != null) {
				vertexTypes.add(sTypeId);
				// for each of its edge
				do {
					byte[] edgeData = edgeEntry.getData();
					long pId = ByteArrayUtil.getLong(edgeData, 0);
					long oId = ByteArrayUtil.getLong(edgeData, 8);
					Long oTypeId = lookupType(oId);
					if (pId != typePredicateId && oTypeId != null) {
						// construct the domain and range of each edge
						getSet(domainByEdge, pId).add(sTypeId);
						getSet(rangeByEdge, pId).add(oTypeId);
					}
					status = edgeCursor.getNextDup(vertexEntry, edgeEntry,
							LockMode.DEFAULT);
				} while (status == OperationStatus.SUCCESS);
				// then, for each of its properties
				status = propertiesCursor.getSearchKey(vertexEntry,
						propertyEntry, LockMode.DEFAULT);
				while (status == OperationStatus.SUCCESS) {
					byte[] propertyIdValue = propertyEntry.getData();
					long propertyId = ByteArrayUtil.getLong(propertyIdValue, 0);
					getSet(propertiesByVertex, sTypeId).add(propertyId);
					// guess type of value
					if (!dataTypeByProperty.containsKey(propertyId)) {
						String propertyValue = new String(propertyIdValue, 8,
								propertyIdValue.length - 8);
						Object value = JSONObject.stringToValue(propertyValue);
						if (value instanceof String) {
							dataTypeByProperty.put(propertyId, "xsd:string");
						} else if (value instanceof Long
								|| value instanceof Integer) {
							dataTypeByProperty.put(propertyId, "xsd:decimal");
						} else if (value instanceof Double) {
							dataTypeByProperty.put(propertyId, "xsd:double");
						} else if (value instanceof Float) {
							dataTypeByProperty.put(propertyId, "xsd:float");
						} else {
							dataTypeByProperty.put(propertyId, "xsd:anyType");
						}
					}
					status = propertiesCursor.getNextDup(vertexEntry,
							propertyEntry, LockMode.DEFAULT);
				}
			}
			status = edgeCursor.getNextNoDup(vertexEntry, edgeEntry,
					LockMode.DEFAULT);
		}

		// now, output schema
		OutputStreamWriter outputStreamWriter = new OutputStreamWriter(output);
		JSONWriter jsonWriter = new JSONWriter(outputStreamWriter);
		jsonWriter.object();
		for (Long vType : vertexTypes) {
			jsonWriter.key(vType.toString());
			jsonWriter.object();
			{
				// edges
				jsonWriter.key("Links");
				jsonWriter.object();
				{
					Set<Long> edgeTypesFromVType = new HashSet<Long>();
					for (Entry<Long, Set<Long>> eTypeDomain : domainByEdge
							.entrySet()) {
						if (eTypeDomain.getValue().contains(vType)) {
							edgeTypesFromVType.add(eTypeDomain.getKey());
						}
					}
					for (Long eType : edgeTypesFromVType) {
						jsonWriter.key(eType.toString());
						jsonWriter.array();
						{
							for (Long targetVType : rangeByEdge.get(eType))
								jsonWriter.value(targetVType);
						}
						jsonWriter.endArray();
					}
				}
				jsonWriter.endObject();
				// properties
				jsonWriter.key("Properties");
				jsonWriter.object();
				{
					Set<Long> vTypeProperties = propertiesByVertex.get(vType);
					for (Long propertyId : vTypeProperties) {
						jsonWriter.key(propertyId.toString());
						jsonWriter.value(dataTypeByProperty.get(propertyId));
					}
				}
				jsonWriter.endObject();
			}
			jsonWriter.endObject();
		}
		jsonWriter.endObject();
		outputStreamWriter.flush();
	}

	private Set<Long> getSet(Map<Long, Set<Long>> domainByEdge, long pId) {
		Set<Long> domain = domainByEdge.get(pId);
		if (domain == null) {
			domain = new HashSet<Long>();
			domainByEdge.put(pId, domain);
		}
		return domain;
	}

	private Cursor typeLookupCursor;
	private DatabaseEntry typeLookupVertexEntry = new DatabaseEntry(new byte[8]);
	private DatabaseEntry typeLookupEdgeEntry = new DatabaseEntry();

	private Long lookupType(long sId) {
		ByteArrayUtil.putLong(sId, typeLookupVertexEntry.getData(), 0);
		OperationStatus status = typeLookupCursor.getSearchKey(
				typeLookupVertexEntry, typeLookupEdgeEntry, LockMode.DEFAULT);
		while (status == OperationStatus.SUCCESS) {
			byte[] edgeData = typeLookupEdgeEntry.getData();
			long pId = ByteArrayUtil.getLong(edgeData, 0);
			if (pId == typePredicateId)
				return ByteArrayUtil.getLong(edgeData, 8);
			status = typeLookupCursor.getNextDup(typeLookupVertexEntry,
					typeLookupEdgeEntry, LockMode.DEFAULT);
		}
		return null;
	}

	public static void main(String[] args) {
		// command line options
		Options options = new Options();
		options.addOption("d", true,
				"Path to working directory for manipulating the graph (Defaults to ./graph/)");
		options.addOption("t", true, "Edge ID for "
				+ RDFDictionaryCodec.RDF_TYPE_PREDICATE_URI);
		options.addOption("i", true, "Load N-Triples in given file");
		options.addOption("o", true,
				"Output Giraph JSON graph to given directory");
		options.addOption("s", true, "Derive encoded schema to given file");
		CommandLine parsedArgs;
		try {
			parsedArgs = new GnuParser().parse(options, args, false);
		} catch (ParseException e) {
			printUsage(options);
			System.exit(1);
			return;
		}

		// process arguments
		String workDirPath = parsedArgs.getOptionValue("d", "graph");
		long typePredicateId = Long
				.valueOf(parsedArgs.getOptionValue("t", "0"));
		String inputNTriplesPath = parsedArgs.getOptionValue("i");
		String outputDirPath = parsedArgs.getOptionValue("o");
		String schemaPath = parsedArgs.getOptionValue("s", "-");
		String[] optionalArgs = parsedArgs.getArgs();
		if (inputNTriplesPath == null && outputDirPath == null
				&& schemaPath == null) {
			printUsage(options);
			System.exit(1);
			return;
		}

		try {
			File workDir = new File(workDirPath);
			workDir.mkdirs();
			RDFGraphTransformer graphTransformer = new RDFGraphTransformer(
					workDir);
			graphTransformer.setTypeEdgeId(typePredicateId);
			if (inputNTriplesPath != null) {
				String filename = inputNTriplesPath;
				InputStream input = filename.equals("-") ? System.in
						: new FileInputStream(filename);
				graphTransformer.loadNTriples(input);
			}
			if (outputDirPath != null) {
				// TODO split into multiple parts
				graphTransformer
						.writeVertexOrientedGraphInJSON(new FileOutputStream(
								new File(outputDirPath, "part-m-00001")));
			}
			if (schemaPath != null) {
				OutputStream output = schemaPath.equals("-") ? System.out
						: new FileOutputStream(schemaPath);
				graphTransformer.deriveSchema(output);
			}
		} catch (RDFParseException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		} catch (RDFHandlerException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		} catch (FileNotFoundException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		} catch (IOException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		} catch (JSONException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		}
	}

	private static void printUsage(Options options) {
		HelpFormatter formatter = new HelpFormatter();
		formatter
				.printHelp(
						"EncodedNTriplesToJSONVertexGraphConverter [OPTIONS] ENCODED_RDF_FILE...",
						options);
		System.out.println();
		System.out.println("FORMAT is one from:\n"
				+ RDFFormat.values().toString());
	}

}

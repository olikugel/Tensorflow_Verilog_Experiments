//Usage:
//BUILD: bazel build tensorflow/examples/rewrittenLabelImage/analyzer
//RUN:   ./bazel-bin/tensorflow/examples/rewrittenLabelImage/analyzer ../tensorflow_image/tensorflow_inception_graph.pb
// (For running the second path points to the graph to be analyzed)

#include <iostream>
#include <fstream>
#include <string>

#include <map>
#include <iomanip>
#include <regex>

#include "tensorflow/core/framework/graph.pb.h"
#include "tensorflow/core/framework/attr_value.pb.h"
#include "tensorflow/core/framework/types.pb.h"

#include <google/protobuf/io/coded_stream.h>
#include <google/protobuf/io/zero_copy_stream_impl.h>
#include <google/protobuf/map.h>
#include <google/protobuf/repeated_field.h>

//#include <boost/graph/adjacency_list.hpp>

//#include <tensorflow/core/framework/tensor.h>
#include "tensorflow/core/framework/tensor.h"

#include <limits>

using namespace std;

// Iterates though all people in the AddressBook and prints info about them.
/*
 * void ListPeople(const tutorial::AddressBook& address_book) {
  for (int i = 0; i < address_book.person_size(); i++) {
    const tutorial::Person& person = address_book.person(i);

    cout << "Person ID: " << person.id() << endl;
    cout << "  Name: " << person.name() << endl;
    if (person.has_email()) {
      cout << "  E-mail address: " << person.email() << endl;
    }

    for (int j = 0; j < person.phone_size(); j++) {
      const tutorial::Person::PhoneNumber& phone_number = person.phone(j);

      switch (phone_number.type()) {
        case tutorial::Person::MOBILE:
          cout << "  Mobile phone #: ";
          break;
        case tutorial::Person::HOME:
          cout << "  Home phone #: ";
          break;
        case tutorial::Person::WORK:
          cout << "  Work phone #: ";
          break;
      }
      cout << phone_number.number() << endl;
    }
  }
}*/

//typedef boost::adjacency_list opGraph;

void statistics(const tensorflow::GraphDef* graph, map<const string, int>* nodeIdMap) {
    cout << "Version (producer):" << graph->versions().producer() << "\n"
                                                                     "\n";
    cout << "Library           \n"
            "  Functions       :" << graph->library().function_size() << "\n"
            "  Gradients       :" << graph->library().gradient_size() << "\n"
                                                                         "\n";
    cout << "Nodes             :" << graph->node_size() << "\n" << endl;

    map<const string, int> operations;

    regex  nodeNameRegex("[A-Za-z0-9.][A-Za-z0-9_./]*");
    smatch match;

    int conv2Dtensors  = 0;
    int maxOutChannels = 0;
    int totalOutChannels = 0;
    int same = 0;
    int valid = 0;

    int strideOccurences[4];

    std::fill_n(strideOccurences, 4, 0);

    for(auto node: graph->node()) {
        auto counter = operations.find(node.op());
        if(counter == operations.end()) {
            //operations.emplace(piecewise_construct, node.op(), 1);
            operations.emplace(node.op(), 1);
        } else {
            counter->second++;
        }

        cout << "Node: " << node.name() << endl;

        if(node.op() == "Conv2D") {
            regex_search(node.input(1), match, nodeNameRegex); //Input 1 == convolution parameters
            if(!match.empty()) {
                auto src = graph->node(nodeIdMap->at(match.str()));
                tensorflow::DataType dataT = src.attr().at("dtype").type();

                if(dataT != tensorflow::DataType::DT_FLOAT) {
                    cout << "Found datatype " << DataType_Name(dataT) << " (" << dataT << ") on node " << node.name() << endl;
                } else {
                    tensorflow::Tensor tensor;
                    if(!tensor.FromProto(src.attr().at("value").tensor())) {
                        cout << "Warning: failed to parse tensor for const node " << node.name() <<endl;
                    } else {
                        cout << "Elements: " << tensor.NumElements() << endl;
                        cout << "Dimensions: " << tensor.shape().dim_size(0) * tensor.shape().dim_size(1) * tensor.shape().dim_size(2)  << ":" << tensor.shape().dim_size(3) << endl;
                        ++conv2Dtensors;
                        if(tensor.shape().dim_size(3) > maxOutChannels) {
                            maxOutChannels = tensor.shape().dim_size(3);
                        }
                        totalOutChannels += tensor.shape().dim_size(3);
                    }
                }
            } else {
                cout << "Failed to find source node " << match.str() << endl;
            }

            if(node.attr().at("padding").s() == "SAME") {
                ++same;
            } else {
                ++valid;
            }

            const google::protobuf::RepeatedField<google::protobuf::int64 >& strides = node.attr().at("strides").list().i();

            int maxStride = 0;
            for(int i=0; i<strides.size(); ++i) {
                //cout << "..  " << setw(4) << strides.Get(i) << "\n";
                if(strides.Get(i) > maxStride) {
                    maxStride = strides.Get(i);
                }
            }

            if(maxStride > 3) {
                cout << "Stride error. Stride " << maxStride << " to large for analyzer." << endl;
                exit(5);
            }

            ++strideOccurences[maxStride];
        }
    }

    cout << "Found " << conv2Dtensors << " Tensors for Conv2D operations.\n\n";
    cout << "Maximum out channels : " << maxOutChannels << "\n";
    cout << "Total out channels : "   << totalOutChannels << endl;
    cout << "Padding Same : " << same << "\n";
    cout << "Padding Valid: " << valid << "\n\n";
    cout << "Stride - Occurences\n";

    for(int i=0; i<4; ++i) {
        cout << i << " - " << strideOccurences[i] << "\n";
    }

    for(auto nodetype: operations) {
        cout << left << setw(50) << nodetype.first << " : " << nodetype.second << "\n";
    }
}

void ListOperations(const tensorflow::GraphDef* graph) {
    //node_size();
    for(auto node: graph->node()) {
        cout << left << setw(50) << node.name() << " : " << node.op() << "\n";
    }
}

/*opGraph buildGraph(const tensorflow::GraphDef* tfgraph) {
    opGraph graph(tfgraph->node_size());

    for(auto node: tfgraph->node()) {
        //add node to graph
    }

    return graph;
}*/

void minInDegree(const tensorflow::GraphDef* graph) {
    int index  = 0;

    for(int i=0; i<graph->node_size(); ++i) {
        if(graph->node(i).input_size() < graph->node(index).input_size()) {
            index = i;
        }
    }

    auto node = &graph->node(index);

    cout << "Min indegree is Node " << node->name() << " (" << index << "). Indegree = " << node->input_size() << endl;
}

void minOutDegree(const tensorflow::GraphDef* graph, map<const string, int>* nodeIdMap) {
    int outdegree[graph->node_size()];
    regex  nodeNameRegex("[A-Za-z0-9.][A-Za-z0-9_./]*"); //"[A-Za-z0-9.][A-Za-z0-9_./]*"
    smatch match;

    for(int i=0; i<graph->node_size(); ++i) {
        outdegree[i] = 0;
    }

    for(auto& node: graph->node()) {
        for(auto input: node.input()) {
            regex_search(input, match, nodeNameRegex);
            //input.
            if(!match.empty()) {
                try {
                    outdegree[nodeIdMap->at(match.str())]++;
                } catch(...) {
                    cout << "ERROR: Failed to map node name to index. Nodename: " << match.str() << "(" << input << ")" << endl;
                    throw;
                }
            } else {
                cout << "NO MATCH FOR NAME " << input << " - " << match.size() << endl;
            }
        }
    }

    int index = 0;

    for(int i=1; i<graph->node_size(); ++i) {
        if(outdegree[i] < outdegree[index]) {
            index = i;
        }
    }

    auto node = &graph->node(index);

    cout << "Min outdegree is Node " << node->name() << " (" << index << "). Outdegree = " << node->input_size() << endl;
}

struct tensorStats_t {
    typedef unsigned long long intStat_t;
    typedef double floatStat_t;

    intStat_t maxDimensions = 0;
    intStat_t minDimensions = 0;

    intStat_t maxNValues = 0;
    intStat_t minNValues = 0;

    floatStat_t maxValue = -std::numeric_limits<float>::infinity();
    floatStat_t minValue =  std::numeric_limits<float>::infinity();

    floatStat_t maxRange = 0;
};

void analyzeRanges(const tensorflow::GraphDef* graph) {
    int consts = 0;

    int typeCounter[11];
    string typeStrings[11] = {"NOT_SET", "list", "string", "int", "float", "bool", "Type", "Shape", "Tensor", "Placeholder", "Function"};

    int tensorTypeCounter[20];
    string tensorTypeStrings[] = {"invalid", "float", "double", "int32", "uint8", "int16", "int8", "string", "complex64", "int64", "bool", "qint8", "quint8", "qint32", "bfloat16", "qint16", "quint16", "uint16", "complex128", "half"};

    std::fill_n(typeCounter, 11, 0);
    std::fill_n(tensorTypeCounter, 20, 0);

    unsigned long long numberOfFloatConstants = 0;
    unsigned long long numberOfNonFloatConstants = 0;

    tensorStats_t stats;

    map<const string, int> nodeToNumberOfConstants;

    int totalNumberOfConsts = 23886351;

    for(auto& node: graph->node()) {
        if(node.op() == "Const") {
            consts++;
            const google::protobuf::Map<string, tensorflow::AttrValue>& attr = node.attr();

            for(auto pair : attr) {
                ++typeCounter[pair.second.value_case()];
                //cout << pair.first << ":" << pair.second.value_case() << endl;
                /* if(pair.first == "value") {
                    cout << "found a value" << endl;
                    break;
                } */
            }

            google::protobuf::Map<string, tensorflow::AttrValue>::const_iterator data = attr.find("dtype");

            if(data != attr.end()) {

                tensorflow::DataType dataT = data->second.type();

                if(dataT > 100) {
                    cout << "ERROR. Found ref type " << dataT << " on node " << node.name() << endl;
                    exit(1);
                }

                if(dataT != tensorflow::DataType::DT_FLOAT) {
                    cout << "Found datatype " << DataType_Name(dataT) << " (" << dataT << ") on node " << node.name() << endl;

                    tensorflow::Tensor tensor;
                    if(!tensor.FromProto(attr.at("value").tensor())) {
                        cout << "Warning: failed to parse tensor for const node " << node.name() <<endl;
                    } else {
                        numberOfNonFloatConstants += tensor.NumElements();

                        if (tensor.NumElements() > (0.01 * totalNumberOfConsts)) {
                          cout << "Node with many non-float Consts: " << node.name() << " --- " << tensor.NumElements() << endl; // << " -- dimensions: " << tensor.DebugString() << endl;
                        }
                    }
                } else {
                    tensorflow::Tensor tensor;
                    if(!tensor.FromProto(attr.at("value").tensor())) {
                        cout << "Warning: failed to parse tensor for const node " << node.name() << endl;
                    } else {
                        numberOfFloatConstants += tensor.NumElements();

                        if (tensor.NumElements() > (0.01 * totalNumberOfConsts)) {
                          cout << "Node with many float Consts: " << node.name() << " --- " << tensor.NumElements() << endl; //  << " -- dimensions: " << tensor.DebugString() << endl;
                        }

                        auto flattened = tensor.flat<float>();

                        //We could write a function that takes a function pointer and a tensor, plus a member pointer for min and one for max respectivley, but no...

                        //float max = flattened.maxCoeff();
                        //float min = flattened.minCoeff();
                        float min =  std::numeric_limits<float>::infinity();
                        float max = -std::numeric_limits<float>::infinity();

                        for(int i=0; i<flattened.size(); ++i) {
                            if(flattened(i) < min) {
                                min = flattened(i);
                            }
                            if(flattened(i) > max) {
                                max = flattened(i);
                            }
                        }

                        if(min < stats.minValue) {
                            stats.minValue = min;
                        }

                        if(max > stats.maxValue) {
                            stats.maxValue = max;
                        }

                        if(max-min > stats.maxRange) {
                            stats.maxRange = max-min;
                        }

                        //tensor.
                    }
                }

                ++tensorTypeCounter[dataT];
            }
        }
    }

    /*
     * Information about the types assigned to const nodes
    */
    cout << "Attribute map type information: (attribute types supplied to const nodes)\n" << endl;

    for(size_t i=0; i<sizeof(typeCounter)/sizeof(decltype(typeCounter[0])); ++i) {
        cout << left << setw(30) << typeStrings[i] << " : " << typeCounter[i] << endl;
    }

    //types used inside tensors
    cout << "Information about types inside tensors:" << endl;

    for(size_t i=0; i<sizeof(tensorTypeCounter)/sizeof(decltype(tensorTypeCounter[0])); ++i) {
        cout << left << setw(30) << tensorTypeStrings[i] << " : " << tensorTypeCounter[i] << endl;
    }

    //Tensor info
    cout << "Number of float constants: " << numberOfFloatConstants << endl;
    cout << "Number of non-float constants: " << numberOfNonFloatConstants << endl;
    cout << "Total number of constants/weights: " << numberOfFloatConstants + numberOfNonFloatConstants << endl;
    cout << "The parameters are in the range " << stats.minValue << " to " << stats.maxValue << " (maxRange:" << stats.maxRange << ")" <<endl;

    // Print how many constants/weights each node carries
    // for(auto elem : nodeToNumberOfConstants)
    // {
    //    cout << elem.first << " --- " << elem.second << endl;
    // }

}

// Main function:  Reads the entire address book from a file and prints all
//   the information inside.
int main(int argc, char* argv[]) {
  // Verify that the version of the library that we linked against is
  // compatible with the version of the headers we compiled against.
  GOOGLE_PROTOBUF_VERIFY_VERSION;

  //we need this when we test limits (this allows us to get -Infinity from -numeric_limits<float>::infinity()
  static_assert(std::numeric_limits<float>::is_iec559, "IEEE 754 required");

  if (argc != 2) {
    cerr << "Usage:  " << argv[0] << " GRAPH_FILE" << endl;
    return -1;
  }

  cout << "Analyzing " << argv[1] << "..." << endl;

  tensorflow::GraphDef graph;

  {
    // Read the existing address book.
    fstream input(argv[1], ios::in | ios::binary);

    //Replacement for graph.ParseFromIstream(&input), which could not be used since we need a bigger message buffer.
    google::protobuf::io::IstreamInputStream stream(&input);
    google::protobuf::io::CodedInputStream   codedStream(&stream);

    codedStream.SetTotalBytesLimit(128 * 1024 * 1024, -1);

    if(!(graph.ParseFromCodedStream(&codedStream) && codedStream.ConsumedEntireMessage() && input.eof())) {
      cerr << "Failed to parse graph." << endl;
      return -1;
    }
  }

  cout << "loaded\n"
          "\n";

  int idCounter = 0;
  map<const string, int> nodeIdMap;

  for(auto node: graph.node()) {
      nodeIdMap.insert(make_pair(node.name(), idCounter++));
  }

  statistics(&graph, &nodeIdMap);
  analyzeRanges(&graph);

  //ListOperations(&graph);

  minInDegree(&graph);
  minOutDegree(&graph, &nodeIdMap);

  //ListPeople(address_book);

  // Optional:  Delete all global objects allocated by libprotobuf.
  google::protobuf::ShutdownProtobufLibrary();

  return 0;
}

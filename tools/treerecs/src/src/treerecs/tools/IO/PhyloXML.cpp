// Copyright (C) 2018  INRIA
//
// Treerecs is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.
//
// Treerecs is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

#include "PhyloXML.h"

// Bpp includes
#include <Bpp/BppString.h>

// Treerecs includes
#include "XMLUtils.h"
#include <assert.h>
#include <treerecs/tools/utils.h>
#include <treerecs/tools/PhyloTreeToolBox.h>

namespace treerecs {

void IPhyloXML::setTaxonomyPhyloXMLTagToPhyloNodeProperty(const std::string &description, bpp::PhyloNode &node,
                                                         std::size_t &cursor) const {
  XMLTag tag_xml = XMLUtils::readNextXMLTag(description, cursor);

  assert(tag_xml.name == "taxonomy" and tag_xml.type == XMLTagType::start);

  if(tag_xml.attributes.find("id_source") != tag_xml.attributes.end()){
    node.setProperty("taxonomy:id_source", bpp::BppString(tag_xml.attributes.at("id_source")));
  }

  tag_xml = XMLUtils::readNextXMLTag(description, cursor);
  while(cursor < description.size() and not(tag_xml.name == "taxonomy" and tag_xml.type == XMLTagType::end)) {
    if(tag_xml.name == "id" and  tag_xml.type == XMLTagType::start) {
      XMLUtils::reachChar(cursor, description, '<', false);
      std::string id = XMLUtils::readXMLElement(description, cursor);
      node.setProperty("taxonomy:id", bpp::BppString(id));
    }

    else if(tag_xml.name == "code" and  tag_xml.type == XMLTagType::start) {
      XMLUtils::reachChar(cursor, description, '<', false);
      std::string code = XMLUtils::readXMLElement(description, cursor);
      node.setProperty("taxonomy:code", bpp::BppString(code));
    }

    else if(tag_xml.name == "scientific_name" and  tag_xml.type == XMLTagType::start) {
      XMLUtils::reachChar(cursor, description, '<', false);
      std::string scientific_name = XMLUtils::readXMLElement(description, cursor);
      node.setProperty("taxonomy:scientific_name", bpp::BppString(scientific_name));
    }

    else if(tag_xml.name == "authority" and  tag_xml.type == XMLTagType::start) {
      XMLUtils::reachChar(cursor, description, '<', false);
      std::string authority = XMLUtils::readXMLElement(description, cursor);
      node.setProperty("taxonomy:authority", bpp::BppString(authority));
    }

    else if(tag_xml.name == "common_name" and  tag_xml.type == XMLTagType::start) {
      XMLUtils::reachChar(cursor, description, '<', false);
      std::string common_name = XMLUtils::readXMLElement(description, cursor);
      node.setProperty("taxonomy:common_name", bpp::BppString(common_name));
    }

    else if(tag_xml.name == "synonym" and  tag_xml.type == XMLTagType::start) {
      XMLUtils::reachChar(cursor, description, '<', false);
      std::string synonym = XMLUtils::readXMLElement(description, cursor);
      node.setProperty("taxonomy:synonym", bpp::BppString(synonym));
    }

    else if(tag_xml.name == "rank" and  tag_xml.type == XMLTagType::start) {
      XMLUtils::reachChar(cursor, description, '<', false);
      std::string rank = XMLUtils::readXMLElement(description, cursor);
      node.setProperty("taxonomy:rank", bpp::BppString(rank));
    }

    else if(tag_xml.name == "uri" and  tag_xml.type == XMLTagType::start) {
      XMLUtils::reachChar(cursor, description, '<', false);
      std::string uri = XMLUtils::readXMLElement(description, cursor);
      node.setProperty("taxonomy:uri", bpp::BppString(uri));
    }

    else {
      //if(tag_xml.type != XMLTagType::end)
      //  std::cerr << "Warning, taxonomy " << tag_xml.name << " tag: bad name or not supported yet." << std::endl;

      if(tag_xml.type == XMLTagType::start)
        XMLUtils::goToEndTag(tag_xml.name, description, cursor);
    }

    tag_xml = XMLUtils::readNextXMLTag(description, cursor);
  }
}

std::shared_ptr<bpp::PhyloNode>
IPhyloXML::phyloXMLCladeToPhyloNode(bpp::PhyloTree &tree, const std::shared_ptr<bpp::PhyloNode> &father_node,
                                   const std::string &description, std::size_t &nodeCounter, std::size_t &cursor) const {
  /*!
   * @details 'Cursor' gives position (in 'description') of the clade start xml tag of the new clade. This will place a
   *          new bpp::PhyloNode in tree as a son of 'father_node'.
   *          If there is no 'father_node' ('= nullptr'), the new node will be inserted without father (like a root).
   */

  XMLTag tag_xml = XMLUtils::readNextXMLTag(description, cursor);

  cursor++;

  assert(tag_xml.type == XMLTagType::start and tag_xml.name == "clade");

  std::shared_ptr<bpp::PhyloNode> current_node (new bpp::PhyloNode());
  std::shared_ptr<bpp::PhyloBranch> edge_to_father (new bpp::PhyloBranch());

  // Check attributes
  // if branch length attribute, set it into the branch/edge to father.
  if(tag_xml.attributes.find("branch_length") != tag_xml.attributes.end()) {
    edge_to_father->setLength(std::atof(tag_xml.attributes.at("branch_length").c_str()));
  }

  // Add node and/ or branch into the tree.
  if(father_node == nullptr){
    tree.createNode(current_node);
  }
  else {
    tree.createNode(father_node, current_node, edge_to_father);
  }

  // Read next tag until the xml closing tag of the current clade.
  tag_xml = XMLUtils::readNextXMLTag(description, cursor);

  cursor++;

  while(not (tag_xml.name == "clade" and tag_xml.type == XMLTagType::end)) {
    // Read inner tags.

    // Add clade with its sons by recursion.
    if (tag_xml.name == "clade" and tag_xml.type == XMLTagType::start) {
      XMLUtils::reachChar(cursor, description, '<', false);
      phyloXMLCladeToPhyloNode(tree, current_node, description, nodeCounter, cursor);
    }

    // Add clade name.
    else if(tag_xml.name == "name" and tag_xml.type == XMLTagType::start) {
      XMLUtils::reachChar(cursor, description, '<', false);
      std::string node_name = XMLUtils::readXMLElement(description, cursor);

      current_node->setName(node_name);
    }

    // Add branch to father length.
    else if(tag_xml.name == "branch_length" and tag_xml.type == XMLTagType::start) {
      XMLUtils::reachChar(cursor, description, '<', false);
      std::string branch_length_str = XMLUtils::readXMLElement(description, cursor);

      double branch_length = atof(branch_length_str.c_str());
      edge_to_father->setLength(branch_length);
    }

    // Add confidence in the branch to father.
    else if(tag_xml.name == "confidence" and tag_xml.type == XMLTagType::start) {
      XMLUtils::reachChar(cursor, description, '<', false);
      std::string confidence_str = XMLUtils::readXMLElement(description, cursor);

      if(edge_to_father)
        edge_to_father->setProperty("bootstrap", bpp::Number<double>(bpp::TextTools::toDouble(confidence_str)));
    }

    // Add clade description in node property.
    else if(tag_xml.name == "description" and tag_xml.type == XMLTagType::start) {
      XMLUtils::reachChar(cursor, description, '<', false);
      std::string description_str = XMLUtils::readXMLElement(description, cursor);

      current_node->setProperty("description", bpp::BppString(description_str));
    }

    // Add taxonomy infos in node property.
    else if(tag_xml.name == "taxonomy" and tag_xml.type == XMLTagType::start) {
      XMLUtils::reachChar(cursor, description, '<', false);
      setTaxonomyPhyloXMLTagToPhyloNodeProperty(description, *current_node, cursor);
    }

    // Default: not supported.
    else {
      //std::cerr << "Unrecognized Clade PhyloXML element called '" << tag_xml.name << "'. Bad name or not supported yet." << std::endl;
      if(tag_xml.type == XMLTagType::start)  cursor = XMLUtils::goToEndTag(tag_xml.name, description, cursor);
    }

    tag_xml = XMLUtils::readNextXMLTag(description, cursor);
    // cursor++;
  }

  // Set indexes in tree.
  tree.setNodeIndex(current_node, (unsigned int) nodeCounter);

  if(edge_to_father) tree.setEdgeIndex(edge_to_father, (unsigned int) nodeCounter);

  // If there is no name for the new node, give the id.
  if(not current_node->hasName()) current_node->setName(std::to_string(nodeCounter));

  // Increment nodeCounter.
  nodeCounter++;

  return current_node;
}

bpp::PhyloTree *IPhyloXML::phylogenyToPhyloTree(const std::string &description, std::size_t &cursor) const {
  /*!
   * @details 'Cursor' gives the position in 'description' of the start tag of the new phylogeny. This method will
   *          create a pointer to a new bpp::PhyloTree.
   */

  XMLTag tag_xml;

  tag_xml = XMLUtils::readNextXMLTag(description, cursor);

  assert(tag_xml.name == "phylogeny" and tag_xml.type == XMLTagType::start);
  if(not (tag_xml.name == "phylogeny" and tag_xml.type == XMLTagType::start)){
    throw bpp::IOException ("PhyloXML: failed to read phylogeny.");
    return NULL;
  }

  // Search of the phylogeny tag.
  while(not (tag_xml.name == "phylogeny" and tag_xml.type == XMLTagType::start)) {
    tag_xml = XMLUtils::readNextXMLTag(description, cursor);
    if(cursor >= (description.size() - 1)){
      std::cerr << "No phylogeny found." << std::endl;
      exit(EXIT_FAILURE);
    }
  }

  cursor++;

  if(cursor >= description.size()) return NULL;

  //else there is a phylogeny, so create a tree.

  bool rooted = false;

  bpp::PhyloTree* tree = new bpp::PhyloTree(rooted);

  std::shared_ptr<bpp::PhyloNode> first_node = nullptr;

  tag_xml = XMLUtils::readNextXMLTag(description, cursor);
  cursor++;

  while(not (tag_xml.name == "phylogeny" and tag_xml.type == XMLTagType::end)) {

    if(tag_xml.name == "name" and tag_xml.type == XMLTagType::start) {
      XMLUtils::reachChar(cursor, description, '<', false);
      std::string tree_name = XMLUtils::readXMLElement(description, cursor);

      tree->setName(tree_name);
    }

    else if(tag_xml.name == "clade" and tag_xml.type == XMLTagType::start) {
      XMLUtils::reachChar(cursor, description, '<', false);
      std::size_t nodeCounter = 0;
      std::shared_ptr<bpp::PhyloNode> created_node = phyloXMLCladeToPhyloNode(*tree, first_node, description, nodeCounter, cursor);
      if(not first_node) first_node = created_node;
    }

    else {
      if(tag_xml.type == start) {
        //std::cerr << "Unrecognized Phylogeny PhyloXML element called '" << tag_xml.name
        //          << "...'. Bad name or not supported yet." << std::endl;
        cursor = XMLUtils::goToEndTag(tag_xml.name, description, cursor, description.size());
      } else if(tag_xml.type != end) {
        //std::cerr << "Unrecognized Phylogeny PhyloXML element called '" << tag_xml.name
        //          << "...'. Bad name or not supported yet." << std::endl;
      }
    }

    tag_xml = XMLUtils::readNextXMLTag(description, cursor);
    cursor++;
  }

  tree->rootAt(first_node);

  return tree;

}

bpp::PhyloTree *IPhyloXML::phyloXMLToPhyloTree(const std::string &description) const {
  /// @details Read and create only the first phylogeny in PhyloXML 'description'.
  std::size_t cursor = 0;

  XMLTag tag_xml = XMLUtils::readNextXMLTag(description, cursor);

  assert(tag_xml.name == "phyloxml" and tag_xml.type == XMLTagType::start);

  if(not(tag_xml.name == "phyloxml" and tag_xml.type == XMLTagType::start)){
    throw bpp::IOException ("PhyloXML: failed to read phyloxml description.");
    return NULL;
  }

  return phylogenyToPhyloTree(description, cursor);
}

std::vector<bpp::PhyloTree *> IPhyloXML::phyloXMLToPhyloTrees(const std::string &description) const {
  /*!
   * @details Read and create trees in a PhyloXML 'description'. Returns std::vector of pointers to bpp::PhyloTree.
   */
  std::size_t cursor = 0;

  XMLTag tag_xml = XMLUtils::readNextXMLTag(description, cursor);

  while(tag_xml.type != XMLTagType::start and tag_xml.name != "phyloxml" and cursor < description.size()) {
    tag_xml = XMLUtils::readNextXMLTag(description, cursor);
  }

  //assert(tag_xml.name == "phyloxml" and tag_xml.type == XMLTagType::start);
  if(not(tag_xml.name == "phyloxml" and tag_xml.type == XMLTagType::start)) {
    throw bpp::IOException ("PhyloXML: error during phyloxml read.");
    return {};
  }

  std::list<bpp::PhyloTree*> trees;

  tag_xml = XMLUtils::readNextXMLTag(description, cursor);
  while(not (tag_xml.name == "phyloxml" and tag_xml.type == XMLTagType::end) ) {
    if(tag_xml.name == "phylogeny" and tag_xml.type == XMLTagType::start) {
      XMLUtils::reachChar(cursor, description, '<', false);
      trees.emplace_back(phylogenyToPhyloTree(description, cursor));
    } else {
      //std::cerr << "Unknown phyloxml tag \"" << tag_xml.name << "\", bad name or not supported yet." << std::endl;
    }

    tag_xml = XMLUtils::readNextXMLTag(description, cursor);
  }
  return {trees.begin(), trees.end()};
}

//  ============================================================================
//  Simon : Reading  eventsRec tag contents in recPhyloXML format
//  ============================================================================
std::shared_ptr<bpp::PhyloNode>
IPhyloXML::recPhyloXMLEventsContentsToPhyloNode(bpp::PhyloTree &tree,
  const std::shared_ptr<bpp::PhyloNode> &father_node,
  const std::string &description,
  std::size_t &nodeCounter,
  std::size_t &cursor,
  bpp::PhyloTree &speciestree,
  const std::string currspecLossLocation,
  int nb_specloss,
  const bool verbose) const {
  /*!
   * @details 'Cursor' gives position (in 'description') of the clade start xml tag of the new clade. This will place a
   *          new loss_node  bpp::PhyloNode in tree as a son of 'father_node'.
   *          and a new intern_loss node    bpp::PhyloNode in tree as a son of 'father_node'.
   *          If there is no 'father_node' ('= nullptr'), the new node will be inserted without father (like a root).
   *          It return the intern_loss node which will be the father for the next speciatiolosss
   *          It uses  currspecLossLocation to determine the loss_nide name
   */
  std::shared_ptr<bpp::PhyloBranch> edge_to_father (new bpp::PhyloBranch());
  std::shared_ptr<bpp::PhyloBranch> edge_to_loss (new bpp::PhyloBranch());
  std::shared_ptr<bpp::PhyloNode> internloss_node (new bpp::PhyloNode()); // artificial node for the bifurcation loss_node / dupliè_node
  std::shared_ptr<bpp::PhyloNode> dupli_node (new bpp::PhyloNode()); // duplication or speciation node under the speciationLoss
  std::shared_ptr<bpp::PhyloNode> loss_node (new bpp::PhyloNode());  // terminal loss node
  std::shared_ptr<bpp::PhyloNode> branchingout_node (new bpp::PhyloNode()); //
  std::string specLossLocation;
  bpp::PhyloTree myspeciestree = speciestree;
  int nb_loss_name = 0 ; // Dealing with speciationLoss in OLD FORMAT :  nb of time the name
                          // the loss node has been detemined. Should be equal to 1
  std::string artificial_node_species ="";
  XMLTag tag_xml = XMLUtils::readNextXMLTag(description, cursor);
  cursor ++;
  std::map<std::string, std::string> tag_attributes_test = tag_xml.attributes;

  // Several cases for which we ent back direcly the father node, ie we do nothing
  // -----------------------------------------------------------------------------
  if (tag_xml.name == "eventsRec" and tag_xml.type == XMLTagType::end ) {
    std::cerr<<"Ending eventsRec"<<std::endl;
    // End of tag
    tag_xml = XMLUtils::readNextXMLTag(description, cursor);
    cursor ++;
    return father_node;
  }
  // Unexpected
  if (tag_xml.name == "clade" and tag_xml.type == XMLTagType::end ) {
      std::cerr<<"Unexpected ending clade"<<std::endl;
      exit(EXIT_FAILURE);
  }
  // XML coding with start and end  <speciation speciesLocation="11"/><speciation speciesLocation="A"></speciation>
  if (tag_xml.name == "speciation" and tag_xml.type == XMLTagType::start and nb_specloss == 0) {
    tag_xml = XMLUtils::readNextXMLTag(description, cursor);
    cursor ++;
    return father_node;
  }
  // XML coding with one line  <speciation speciesLocation="11"/>
  if (tag_xml.name == "speciation" and tag_xml.type == XMLTagType::oneline and nb_specloss == 0) {
    return father_node;
  }
  if (tag_xml.name == "leaf" and tag_xml.type == XMLTagType::start and nb_specloss == 0) {
    tag_xml = XMLUtils::readNextXMLTag(description, cursor);
    cursor ++;
    return father_node;
  }
  if (tag_xml.name == "leaf" and tag_xml.type == XMLTagType::oneline and nb_specloss == 0) {
    return father_node;
  }
  if (tag_xml.name == "duplication" and tag_xml.type == XMLTagType::start and nb_specloss == 0) {
    tag_xml = XMLUtils::readNextXMLTag(description, cursor);
    cursor ++;
    return father_node;
  }
  if (tag_xml.name == "duplication" and tag_xml.type == XMLTagType::oneline and nb_specloss == 0) {
    return father_node;
  }
  if (tag_xml.name == "transferBack" and tag_xml.type == XMLTagType::start) {
    cursor++;
    return recPhyloXMLEventsContentsToPhyloNode(tree, father_node, description, nodeCounter, cursor,speciestree,specLossLocation,nb_specloss,verbose);
  }
  if (tag_xml.name == "transferBack" and tag_xml.type == XMLTagType::oneline) {
    return recPhyloXMLEventsContentsToPhyloNode(tree, father_node, description, nodeCounter, cursor,speciestree,specLossLocation,nb_specloss,verbose);
  }
  if (tag_xml.name == "bifurcationOut/") {
    //  This a  bifurcation ( dupli or speci whatever ) in a branch wich is ouside the species tree
    return father_node;
  }
  if (tag_xml.name == "bifurcationOut" and tag_xml.type == XMLTagType::oneline) {
    //  This a  bifurcation ( dupli or speci whatever ) in a branch wich is ouside the species tree
    // cursor++;
    return father_node;
  }
  if (tag_xml.name == "bifurcationOut" and tag_xml.type == XMLTagType::start) {
    //  This a  bifurcation ( dupli or speci whatever ) in a branch wich is ouside the species tree
    cursor ++;
    return father_node;
  }
  if (tag_xml.name == "branchingOut" and tag_xml.type == XMLTagType::oneline) {
    std::map<std::string, std::string> tag_attributes = tag_xml.attributes;
    std::string node_species;
    for (std::map<std::string,std::string>::iterator it=tag_attributes.begin(); it!=tag_attributes.end(); ++it){
      if (it->first == "speciesLocation") {
        node_species = it->second;
      }
    }
    if (verbose) std::cerr<<"Gene node name modification: "<< father_node->getName();
    father_node->setName(node_species+"_"+std::to_string(nodeCounter)+"_bout");
    if (verbose) std::cerr<<" is now named "<< father_node->getName()<<std::endl;

    return father_node;
    }
    if (tag_xml.name == "branchingOut" and tag_xml.type == XMLTagType::start) {
      std::map<std::string, std::string> tag_attributes = tag_xml.attributes;
      std::string node_species;
      for (std::map<std::string,std::string>::iterator it=tag_attributes.begin(); it!=tag_attributes.end(); ++it){
        if (it->first == "speciesLocation") {
          node_species = it->second;
        }
      }

      if (verbose) std::cerr<<"Gene node name modification: "<< father_node->getName();
      father_node->setName(node_species+"_"+std::to_string(nodeCounter)+"_bout");
      if (verbose) std::cerr<<" is now named "<< father_node->getName()<<std::endl;
      cursor ++;
      return father_node;
    }
  // LEAF AFTER AT LEAST 1 SPECIATION LOSS (OLD FORMAT)
  // ==================================================
  // We want a bifurcation with a terminal loss node and a terminal leaf node
  if (tag_xml.name == "leaf" and tag_xml.type == XMLTagType::start and nb_specloss > 0) {
    // std::cerr <<"========= WARNING! THIS IS A LEAF WITHIN  OLD FORMAT SPECIATION LOSS ================= "<<std::endl;
    std::map<std::string, std::string> tag_attributes = tag_xml.attributes;
    std::string node_name;
    std::string node_species;
    std::string artificial_node_species ="";
    nb_loss_name =0;
    // Get name and species associated to the leaf node
    // <leaf geneName="b1_b" speciesLocation="b"></leaf>
    for (std::map<std::string,std::string>::iterator it=tag_attributes.begin(); it!=tag_attributes.end(); ++it){
      if (it->first == "geneName") {
        node_name = it->second;
      }
      if (it->first == "speciesLocation") {
        node_species = it->second;
      }
    }
    // Search currspecLossLocation in the speciestree, get the 2 sons and compare its associated species to the leaf spcies.
    // The species different from the leaf is the species associated to the loss, thus is used to define the name of loss_node
    for(const auto& gene: myspeciestree.getAllNodes()) {
      bpp::PhyloNode bof = *gene;
      if (bof.getName() == currspecLossLocation){
        // The species is found in the species tree
        for(const auto& son: myspeciestree.getSons(gene)) {
          bpp::PhyloNode bofson = *son;
          if (bofson.getName() ==  node_species) {
          }
          else{
            artificial_node_species = bofson.getName();
            nb_loss_name ++;
          }
        }
      }
    }
    // The artificial_node_specie should have detected one  and only one?
    if (nb_loss_name !=1) {
      std::cerr<<"Unable to detect the species associated to the loss"<<std::endl;
      exit(EXIT_FAILURE);
    }
    // Set the name of the loss node
    loss_node->setName(artificial_node_species+"_loss");
    loss_node->setName(artificial_node_species+ "_"+ std::to_string(nodeCounter)+"_loss");
    // Define the leaf node
    std::shared_ptr<bpp::PhyloNode> leaf_node (new bpp::PhyloNode());
    // Set the name of the leaf node
    leaf_node->setName(node_name);
    // Add the leaf to the father
    tree.createNode(father_node,leaf_node, edge_to_father);
    tree.setNodeIndex(leaf_node, (unsigned int) nodeCounter);
    nodeCounter++;
    // Add the loss to the father
    tree.createNode(father_node,loss_node, edge_to_loss);
    tree.setNodeIndex(loss_node, (unsigned int) nodeCounter);
    nodeCounter++;
    nb_specloss ++;
    // We do not defined internloss node, so the function will sebd back
    // an null node
  }
  // DUPLICATION AFTER AT LEAST 1 SPECIATION LOSS (OLD FORMAT)
  // =========================================================
  // We want a bifurcation with a terminal loss node and a duplication node
  else if (tag_xml.name == "duplication" and tag_xml.type == XMLTagType::start and nb_specloss > 0)  {
    // std::cerr <<"========= WARNING! THIS IS A DUPLICATION WITHIN  OLD FORMAT SPECIATION LOSS ================= "<<std::endl;
    std::map<std::string, std::string> tag_attributes = tag_xml.attributes;
    std::string node_species;
    std::string artificial_node_species ="";
    // Get the species associated to the duplication
    // <duplication speciesLocation="a"></duplication>
    for (std::map<std::string,std::string>::iterator it=tag_attributes.begin(); it!=tag_attributes.end(); ++it){
      if (it->first == "speciesLocation") {
        node_species = it->second;
      }
    }
    // Search currspecLossLocation in the speciestree, get the 2 sons and compare its associated species to the duplication node  spcies.
    // The species different from the duplication node  is the species associated to the loss, thus is used to define the name of loss_node
    nb_loss_name =0;
    for(const auto& gene: myspeciestree.getAllNodes()) {
      bpp::PhyloNode bof = *gene;
      if (bof.getName() == currspecLossLocation){
        for(const auto& son: myspeciestree.getSons(gene)) {
          bpp::PhyloNode bofson = *son;
          if (bofson.getName() ==  node_species) {
          }
          else{
            artificial_node_species = bofson.getName();
            nb_loss_name ++;
          }
        }
      }
    }
    if (nb_loss_name !=1) {
      std::cerr<<"Unable to detect the species associated to the loss"<<std::endl;
      exit(EXIT_FAILURE);
    }
    // Set loss_node  name
    loss_node->setName(artificial_node_species+"_loss");
     loss_node->setName(artificial_node_species+ "_"+ std::to_string(nodeCounter)+"_loss");

    // Set duplication node name
    dupli_node->setName(node_species+"_dupl");
    dupli_node->setName(node_species+ "_"+ std::to_string(nodeCounter)+"_dupl");
    // Add duplication node  to the father.
    tree.createNode(father_node,dupli_node, edge_to_father);
    tree.setNodeIndex(dupli_node, (unsigned int) nodeCounter);
    nodeCounter++;

    // Addd the  loss_node to the father
    tree.createNode(father_node,loss_node, edge_to_loss);
    tree.setNodeIndex(loss_node, (unsigned int) nodeCounter);
    nodeCounter++;
    nb_specloss ++;
    // Send back duplication node
    internloss_node=dupli_node;
  }
  // SPECIATIONCATION AFTER AT LEAST 1 SPECIATION LOSS (OLD FORMAT)
  // =============================================================
  // We want a bifurcation with a terminal loss node and a speciation node
  else if (tag_xml.name == "speciation" and ( tag_xml.type == XMLTagType::start or tag_xml.type == XMLTagType::oneline ) and nb_specloss > 0)  {
    // std::cerr <<"========= WARNING! THIS IS A SPECIATION WITHIN  OLD FORMAT SPECIATION LOSS ================= "<<std::endl;
    std::map<std::string, std::string> tag_attributes = tag_xml.attributes;
    std::string node_species;
    std::string artificial_node_species ="";
    //Get the species associated to the speciation
    // <specication speciesLocation="b"></duplication>
    for (std::map<std::string,std::string>::iterator it=tag_attributes.begin(); it!=tag_attributes.end(); ++it){
      if (it->first == "speciesLocation") {
        node_species = it->second;
      }
    }
    // Search currspecLossLocation in the speciestree, get the 2 sons and compare its associated species to the speciation node  spcies.
    // The species different from the speciation node  is the species associated to the loss, thus is used to define the name of loss_node
    nb_loss_name =0;
    for(const auto& gene: myspeciestree.getAllNodes()) {
      bpp::PhyloNode bof = *gene;
      if (bof.getName() == currspecLossLocation){
        for(const auto& son: myspeciestree.getSons(gene)) {
          bpp::PhyloNode bofson = *son;
          if (bofson.getName() ==  node_species) {
          }
          else{
            artificial_node_species = bofson.getName();
            nb_loss_name ++;
          }
        }
      }
    }
    if (nb_loss_name !=1) {
      std::cerr<<"Unable to detect the species associated to the loss"<<std::endl;
      exit(EXIT_FAILURE);
    }
    // Set the name of the loss node
    loss_node->setName(artificial_node_species+"_loss");
    loss_node->setName(artificial_node_species+ "_"+ std::to_string(nodeCounter)+"_loss");
    XMLUtils::reachChar(cursor, description, '<', false);
    // Set the name of the speciation node
    dupli_node->setName(node_species+"_spec");
    dupli_node->setName(node_species+ "_"+ std::to_string(nodeCounter)+"_spec");
    // Add  the speciation node to the father
    tree.createNode(father_node,dupli_node, edge_to_father);
    tree.setNodeIndex(dupli_node, (unsigned int) nodeCounter);
    nodeCounter++;
    // Add  the loss node to the father
    tree.createNode(father_node,loss_node, edge_to_loss);
    tree.setNodeIndex(loss_node, (unsigned int) nodeCounter);
    nodeCounter++;
    //  Send back speciation node
    internloss_node=dupli_node;
  }
  // SPECIATIONLOSS (OLD FORMAT)
  // ===========================
  else if (tag_xml.name == "speciationLoss" and tag_xml.type == XMLTagType::start) {
    // std::cerr <<"========= WARNING! OLD FORMAT SPECIATIONLOSS DETECTED ================= "<<std::endl;
    cursor++;
    while(not (tag_xml.name == "speciationLoss" and tag_xml.type == XMLTagType::end)) {
      //Get the species associated to speciationLoss
      // <speciationLoss speciesLocation="1"></speciationLoss>
      std::map<std::string, std::string> tag_attributes = tag_xml.attributes;
      for (std::map<std::string,std::string>::iterator it=tag_attributes.begin(); it!=tag_attributes.end(); ++it){
        if (it->first == "speciesLocation") {
          specLossLocation = it->second;
        }
      }
      if (nb_specloss == 0){
        //  This is the first  speciationLoss, I create a loss_node under the
         // father node  by recursivity,
        // I will get back either nothing either a speciation, either a
         // duplication,  either an internloss
        nb_specloss  ++;
        loss_node = recPhyloXMLEventsContentsToPhyloNode(tree, father_node, description, nodeCounter, cursor,speciestree,specLossLocation,nb_specloss,verbose);
      }
      else {
        // Search currspecLossLocation in the speciestree, get the 2 sons and
        // compare its associated species to the speciation node  species.
        // The species different from the speciationLoss node  is the species
         // associated to the loss, thus is used to define the name of loss_node
        nb_loss_name =0;
        for(const auto& gene: myspeciestree.getAllNodes()) {
          bpp::PhyloNode bof = *gene;
          if (bof.getName() == currspecLossLocation){
            for(const auto& son: myspeciestree.getSons(gene)) {
              bpp::PhyloNode bofson = *son;
              if (bofson.getName() ==  specLossLocation) {
              }
              else{
                artificial_node_species = bofson.getName();
                nb_loss_name ++;
              }
            }
          }
        }
        // We expect to have found one and only one time a name for the loss
        if (nb_loss_name !=1) {
          exit(EXIT_FAILURE);
        }
        // Set the name of the loss node
        loss_node->setName(artificial_node_species+"_loss");
        loss_node->setName(artificial_node_species+ "_"+ std::to_string(nodeCounter)+"_loss");
        // Set the name of the internloss_node node
        internloss_node->setName(specLossLocation+"_loss");
        internloss_node->setName(specLossLocation+ "_"+ std::to_string(nodeCounter)+"_loss");
        // internloss_node->setName(specLossLocation+"_speciation");
        nb_specloss ++;
        // Adding internloss_node to the dather
        tree.createNode(father_node,internloss_node, edge_to_father);
        tree.setNodeIndex(internloss_node, (unsigned int) nodeCounter);
        nodeCounter++;
        // Adding loss_node to the father
        tree.createNode(father_node,loss_node, edge_to_loss);
        tree.setNodeIndex(loss_node, (unsigned int) nodeCounter);
        nodeCounter++;
        // create a loss_node under tha internloss_node  by recursivity,
        // I will get back either nothing either a speciation, either a duplication,  either an internloss
        loss_node = recPhyloXMLEventsContentsToPhyloNode(tree, internloss_node, description, nodeCounter, cursor,speciestree,specLossLocation,nb_specloss,verbose);
      }
      //  In case of SpeciatLoss, send back the loss_node
      return loss_node;
    }
  }
  // LOSS new format
  // ===================
  if (tag_xml.name == "loss" and tag_xml.type == XMLTagType::start) {
    tag_xml = XMLUtils::readNextXMLTag(description, cursor);
    cursor ++;
    father_node->setProperty("isArtificialGene",IsArtificialGene(true));
    return father_node;
  }
  if (tag_xml.name == "loss" and tag_xml.type == XMLTagType::oneline) {
    father_node->setProperty("isArtificialGene",IsArtificialGene(true));
    return father_node;
  }
  // Leaving speciatioLosss
  // ======================
  // std::cerr <<"========= WARNING! OLD FORMAT SPECIATIONLOSS END TAG ================= "<<std::endl;
  tag_xml = XMLUtils::readNextXMLTag(description, cursor);
  cursor ++;
  return internloss_node;
}
//  ============================================================================
//  Simon : Reading  eventsRec tag in recPhyloXML format
//  ============================================================================
std::shared_ptr<bpp::PhyloNode>
IPhyloXML::recPhyloXMLEventsToPhyloNode(bpp::PhyloTree &tree,
  const std::shared_ptr<bpp::PhyloNode> &father_node,
  const std::string &description,
  std::size_t &nodeCounter,
  std::size_t &cursor,
  bpp::PhyloTree &speciestree,
  const bool verbose) const {
  /*!
   * @details 'Cursor' gives position (in 'description') of the clade start xml tag of the new clade. This will place a
   *          new bpp::PhyloNode in tree as a son of 'father_node'.
   *          If there is no 'father_node' ('= nullptr'), the new node will be inserted without father (like a root).
   */
  XMLTag tag_xml = XMLUtils::readNextXMLTag(description, cursor);
  std::map<std::string, std::string> tag_attributes_test = tag_xml.attributes;
  assert(tag_xml.type == XMLTagType::start and tag_xml.name == "eventsRec");
  if (!(tag_xml.type == XMLTagType::start and tag_xml.name == "eventsRec")){
    std::cerr << "Expecting starting  <eventsRec>" <<std::endl;
    exit(EXIT_FAILURE);
  }
  std::shared_ptr<bpp::PhyloNode> node (new bpp::PhyloNode());
  std::string specLossLocation; // Dealing with old format
  std::string currspecLossLocation; // Dealing with old format
  node = recPhyloXMLEventsContentsToPhyloNode(tree, father_node, description, nodeCounter, cursor,speciestree,specLossLocation,0,verbose);
  tag_xml = XMLUtils::readNextXMLTag(description, cursor); // Read the next tag
  cursor++;
  return node;
}

//  ============================================================================
//  Simon : reading a clade with recPhyloXML format.
//  This a recursive fonction since clades are nested.
//  This is a modfied version of phyloXMLCladeToPhyloNode
//  ============================================================================
std::shared_ptr<bpp::PhyloNode>
IPhyloXML::recPhyloXMLCladeToPhyloNode(bpp::PhyloTree &tree,
  const std::shared_ptr<bpp::PhyloNode> &father_node,
  const std::string &description,
  std::size_t &nodeCounter,
  std::size_t &cursor,
  bpp::PhyloTree &speciestree,
  std::map<std::string,int> &occurLeaves,
  int &inc2,
  const bool verbose) const {
  /*!
   * @details 'Cursor' gives position (in 'description') of the clade start xml tag of the new clade. This will place a
   *          new bpp::PhyloNode in tree as a son of 'father_node'.
   *          If there is no 'father_node' ('= nullptr'), the new node will be inserted without father (like a root).
   *          for recPhylo:- species tree is needed to deal with speciationLoss tags
   *                       - occureLeaves and inc2 are used to deal with redondant names.
   */
  XMLTag tag_xml = XMLUtils::readNextXMLTag(description, cursor);
  if (!(tag_xml.type == XMLTagType::start and tag_xml.name == "clade")){
    std::cerr<<"Error: this is not a starting clade"<<std::endl;
      exit(EXIT_FAILURE);
  };
   std::map<std::string,int> ::iterator itOcc;
  std::shared_ptr<bpp::PhyloNode> current_node (new bpp::PhyloNode());
  std::shared_ptr<bpp::PhyloBranch> edge_to_father (new bpp::PhyloBranch());
  // Check attributes
  // if branch length attribute, set it into the branch/edge to father.
  if(tag_xml.attributes.find("branch_length") != tag_xml.attributes.end()) {
    edge_to_father->setLength(std::atof(tag_xml.attributes.at("branch_length").c_str()));
  }
  // Add node and/ or branch into the tree.
  if(father_node == nullptr){
    tree.createNode(current_node);
  }
  else {
    tree.createNode(father_node, current_node, edge_to_father);
  }
  // Read next tag until the xml closing tag of the current clade.
  tag_xml = XMLUtils::readNextXMLTag(description, cursor);
  while(not (tag_xml.name == "clade" and tag_xml.type == XMLTagType::end) ) {
    // Add clade with its sons by recursion.
    if (tag_xml.name == "clade" and tag_xml.type == XMLTagType::start) {
      XMLUtils::reachChar(cursor, description, '<', false);
      recPhyloXMLCladeToPhyloNode(tree, current_node, description, nodeCounter, cursor,speciestree,occurLeaves,inc2,verbose);
    }
    //Set clade name.
    else if(tag_xml.name == "name" and tag_xml.type == XMLTagType::start) {
      XMLUtils::reachChar(cursor, description, '<', false);
      std::string node_name = XMLUtils::readXMLElement(description, cursor);
      // Dealing with redondance in nodes name
      itOcc=occurLeaves.find(node_name);
      if (itOcc == occurLeaves.end()){
        // If the node name is not found, add it to the map
        occurLeaves.emplace(node_name,1);
      }
      else {
        // if the node exists increment the index inc2 and modify the node name
        // the same inc2 index is used for the whole data of recPhyloXML
        inc2++;
        if (verbose) std::cerr << "Detecting redundant name in gene tree :  "<<node_name;
        node_name.append(std::to_string(inc2));
        if (verbose) std::cerr << " is now "<<node_name<<std::endl;
      }
      current_node->setName(node_name);
    }
    // Add events rec
    else if (tag_xml.name == "eventsRec" and tag_xml.type == XMLTagType::start) {
      XMLUtils::reachChar(cursor, description, '<', false);
      std::shared_ptr<bpp::PhyloNode> test_node (new bpp::PhyloNode());
      //  Get a node from the EventsRec tag
      test_node = recPhyloXMLEventsToPhyloNode(tree, current_node, description, nodeCounter, cursor,speciestree,verbose);
      // Simon ici verbos e= 0
      // Check the node
      // Note : This is related to te old format tag "speciationLoss"
      // if the node is an articial node from a duplication or a speciation  occuring after a loss, next 2 clade should be added
      // to this node and not to the current node. Thus we set current_node to test_node
      if (test_node->hasName()) {
        std::string test_name = test_node->getName();
        if (test_name.length() >5) {
          if (test_name.substr(test_name.length()-5,5) == "_dupl") {
             current_node = test_node;
          }
          if (test_name.substr(test_name.length()-5,5) == "_spec") {
             current_node = test_node;
          }
        }
      }
    }
    // Default: not supported.
    else {
      std::cerr << "Unrecognized Clade PhyloXML element called '" << tag_xml.name << "'. Bad name or not supported yet." << std::endl;
      if(tag_xml.type == XMLTagType::start)  cursor = XMLUtils::goToEndTag(tag_xml.name, description, cursor);
    }
     //  Next tag
    tag_xml = XMLUtils::readNextXMLTag(description, cursor);
  }
  // Exit from the current clade
  tree.setNodeIndex(current_node, (unsigned int) nodeCounter);
  // Increment nodeCounter.
  nodeCounter++;
  if(edge_to_father) tree.setEdgeIndex(edge_to_father, (unsigned int) nodeCounter);
  // If there is no name for the new node, give the id.
  if(not current_node->hasName()) current_node->setName(std::to_string(nodeCounter));
  return current_node;
}

// Simon : reading phylogeny with recPhyloXML format
bpp::PhyloTree *IPhyloXML::recPhylogenyToPhyloTree(const std::string &description, std::size_t &cursor,const std::shared_ptr<bpp::PhyloTree> speciestree, const bool verbose ) const {
  /*!
   * @details 'Cursor' gives the position in 'description' of the start tag of the new phylogeny. This method will
   *          create a pointer to a new bpp::PhyloTree.
   */
  XMLTag tag_xml;
  tag_xml = XMLUtils::readNextXMLTag(description, cursor);
  assert(tag_xml.name == "phylogeny" and tag_xml.type == XMLTagType::start);
  if(not (tag_xml.name == "phylogeny" and tag_xml.type == XMLTagType::start)){
    throw bpp::IOException ("recPhyloXML: failed to read phylogeny.");
    return NULL;
  }
  bool rooted = false;
  bpp::PhyloTree* tree = new bpp::PhyloTree(rooted);
  std::shared_ptr<bpp::PhyloNode> first_node = nullptr;
  tag_xml = XMLUtils::readNextXMLTag(description, cursor);

  // initialization of variable which will be used to deal with redondant gene names:
   int inc2gene = 0;                              // Set to 0
   std::map<std::string,int> occurLeavesGene;    // Empty

  // Read intil the next </phylogeny> tag
  while(not (tag_xml.name == "phylogeny" and tag_xml.type == XMLTagType::end)) {
    if(tag_xml.name == "name" and tag_xml.type == XMLTagType::start) {
      // Tree name
      XMLUtils::reachChar(cursor, description, '<', false);
      std::string tree_name = XMLUtils::readXMLElement(description, cursor);
      tree->setName(tree_name);
    }
    else if(tag_xml.name == "clade" and tag_xml.type == XMLTagType::start) {
      XMLUtils::reachChar(cursor, description, '<', false);
      std::size_t nodeCounter = 0;
      std::shared_ptr<bpp::PhyloNode> created_node = recPhyloXMLCladeToPhyloNode(*tree, first_node, description, nodeCounter, cursor,*speciestree, occurLeavesGene, inc2gene, verbose);
      if(not first_node) first_node = created_node;
    }
    else {
      if(tag_xml.type == start) {
        std::cerr << "Unrecognized Phylogeny PhyloXML element called '" << tag_xml.name<< std::endl;
        std::cerr << "...'. Bad name or not supported yet." << std::endl;
        cursor = XMLUtils::goToEndTag(tag_xml.name, description, cursor, description.size());
      } else if(tag_xml.type != end) {
        std::cerr << "Unrecognized Phylogeny PhyloXML element called '" << tag_xml.name<< std::endl;
        std::cerr << "...'. Bad name or not supported yet." << std::endl;
      }
    }
    tag_xml = XMLUtils::readNextXMLTag(description, cursor);
  }
  tree->rootAt(first_node);
  return tree;
}

// Simon : reading one or more  trees in recPhyloXML format
std::vector<bpp::PhyloTree *> IPhyloXML::recPhyloXMLToPhyloTrees(const std::string &description, const std::shared_ptr<bpp::PhyloTree> speciestree, const bool verbose) const {
  /*!
   * @details Read and create trees in a recPhyloXML 'description'. Returns std::vector of pointers to bpp::PhyloTree.
   */
  std::size_t cursor = 0;
  XMLTag tag_xml = XMLUtils::readNextXMLTag(description, cursor);
  std::list<bpp::PhyloTree*> trees;

  // Simon : If a species tree is defined, it means that we want to read one or several gene trees in the recPhyloXML file
  // We need the species tree to defined artificial nodes
  if (speciestree != nullptr) {
    // Go to the first <recGeneTree> tag
    while(tag_xml.name != "recGeneTree" and cursor < description.size()) {
      tag_xml = XMLUtils::readNextXMLTag(description, cursor);
    }
    if(not(tag_xml.name == "recGeneTree" and tag_xml.type == XMLTagType::start)) {
      throw bpp::IOException ("RecPhyloXML: error during recphyloxml read.");
      return {};
    }
    tag_xml = XMLUtils::readNextXMLTag(description, cursor);
    // Reading gene for each  <phymogeny> tag
    while( cursor < description.size() ) {
      if(tag_xml.name == "phylogeny" and tag_xml.type == XMLTagType::start) {
        // std::cout <<"Analysing <phylogeny> tag for gene tree..." <<std::endl;
        XMLUtils::reachChar(cursor, description, '<', false);
        // Read the  phylogeny of the gene tree in recPhyloXML format and add it to 'trees'
        trees.emplace_back(recPhylogenyToPhyloTree(description, cursor,speciestree,verbose));
      }
      tag_xml = XMLUtils::readNextXMLTag(description, cursor);
    }
  }
  // If a species tree is not  defined, it means that we want to read or the species trees in the recPhyloXML file
  // We will need  the species tree when reading the gene trees
  else {
    // Reach the first  <spTree> tag
    while(tag_xml.name != "spTree" and cursor < description.size()) {
       tag_xml = XMLUtils::readNextXMLTag(description, cursor);
    }
    if(not(tag_xml.name == "spTree" and tag_xml.type == XMLTagType::start)) {
       throw bpp::IOException ("RecPhyloXML: error during recphyloxml read.");
      return {};
    }
    tag_xml = XMLUtils::readNextXMLTag(description, cursor);
    while(not (tag_xml.name == "spTree" and tag_xml.type == XMLTagType::end) and cursor < description.size() ) {
       if(tag_xml.name == "phylogeny" and tag_xml.type == XMLTagType::start) {
        XMLUtils::reachChar(cursor, description, '<', false);
        // std::cout <<"Analysing <phylogeny> tag for species tree..." <<std::endl;
        // Read the  phylogeny of the species tree in PhyloXML format and add it to 'trees'
        trees.emplace_back(phylogenyToPhyloTree(description, cursor));
      }
      tag_xml = XMLUtils::readNextXMLTag(description, cursor);
    }
  }
  return {trees.begin(), trees.end()};
}

const std::string IPhyloXML::getFormatName() const { return "PhyloXML"; }

const std::string IPhyloXML::getFormatDescription() const {
  return getFormatName()
         + ", XML for evolutionary biology and comparative genomics. See http://www.phyloxml.org for more info.";
}

bpp::PhyloTree *IPhyloXML::readP(std::istream &in) const {
  // Checking the existence of specified file
  if (! in) { throw bpp::IOException ("PhyloXML::read: failed to read from stream"); }

  std::string description((std::istreambuf_iterator<char>(in)), std::istreambuf_iterator<char>());

  if (bpp::TextTools::isEmpty(description))
    throw bpp::IOException("PhyloXML::read: no tree has been found!");
  return phyloXMLToPhyloTree(description);
}

void IPhyloXML::read(const std::string &path, std::vector<bpp::PhyloTree *> &trees) const {
  std::ifstream in(path.c_str(), std::ios::in);
  if (! in) { throw bpp::IOException ("PhyloXML::read: failed to read from stream"); }
  read(in, trees);
}

void IPhyloXML::read(std::istream &in, std::vector<bpp::PhyloTree *> &trees) const {
  if (! in) { throw bpp::IOException ("PhyloXML::read: failed to read from stream"); }

  std::string description((std::istreambuf_iterator<char>(in)), std::istreambuf_iterator<char>());

  if (bpp::TextTools::isEmpty(description))
    throw bpp::IOException("PhyloXML::read: no tree was found!");

  trees = phyloXMLToPhyloTrees(description);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

std::string OPhyloXML::geneNameField = "geneName=";
std::string OPhyloXML::speciesField = "speciesLocation=";

/// Create an indentation.
std::string OPhyloXML::line_indentation(const std::size_t indent_level) const {
  return std::string(indent_level, ' ');
  //std::string res;
  //while(res.size() < indent_level) res += ' ';
  //return res;
}

/// Create an opening_tag.
std::string OPhyloXML::opening_tag(const std::string &field, const std::string& param, const std::string& value) const {
  return "<" + field
         + (not param.empty() ? (" " + param + (not value.empty() ? ("=" + value) : "")) : "")
         + ">";
}

/// Create a closing tag.
std::string OPhyloXML::closing_tag(const std::string &field) const {
  return "</" + field + ">";
}

/// Print a RecPhyloXML event in output (std::ostream).
void OPhyloXML::eventToPhyloXML(std::ostream &output, const Node &gene_node, std::unordered_map<Node, Event> &associated_events,
                                  const std::size_t indent_level) const {
  Event event = associated_events.at(gene_node);

  if(event == none) return;

  bpp::BppString& species_node = *dynamic_cast<bpp::BppString*>(gene_node->getProperty("Species name"));

  // Begin line
  output << line_indentation(indent_level);

  // First opening field <...>
  output << "<" << event ;

  if(event == extant) {
    if(gene_node->hasName()) {
      output << " " << geneNameField << "\"" << gene_node->getName() << "\"";
    }
  }

  if(event != bifurcationOut) {
    output << " ";
    output << speciesField;
    output << "\"";
    output << species_node;
    output << "\"";
  }

  output << ">";

  // Second ending field </>
  output << closing_tag(event_to_str(event)) << std::endl;

  return;
}

/// Print a RecPhyloXML node in output.
void OPhyloXML::nodeToRecPhyloXML(std::ostream &output, const Node &gene_node, const bpp::PhyloTree &genetree,
                                  std::unordered_map<Node, Event> &associated_events,
                                  std::size_t indent_level) const {

  Event event = associated_events.at(gene_node);
  if(event == none)// ignoring any Null event.
  {
    auto children = genetree.getSons(gene_node);
    nodeToRecPhyloXML(output, children.front(), genetree, associated_events, indent_level);//recursion on the first (and only) son of the null node
  }
  else
  {
    output << line_indentation(indent_level);
    output << opening_tag("clade") << std::endl;
    indent_level++;

    //writing the different informations:

    //1. name:
    output << line_indentation(indent_level);
    output << opening_tag("name");
    if(gene_node->hasName())
    {
      output << gene_node->getName();
    }
    else
    {
      output << "noname";
    }
    output << closing_tag("name") << std::endl;

    //2. the reconciliation event(s)
    output << line_indentation(indent_level);
    output << opening_tag("eventsRec") << std::endl;
    indent_level++;

    auto current_gene_node = gene_node;
    auto next_gene_node = current_gene_node;
    bool donext = true;

    while( donext )
    {
      current_gene_node = next_gene_node; //iteration

      auto children = genetree.getSons(current_gene_node);

      if(children.size() == 0)
        donext = false;

      for(unsigned i = 0 ; i < children.size(); i++)
      {
        auto event = associated_events.at(children[i]);
        if(event != loss) {
          if(next_gene_node  == current_gene_node)//this is the first non-loss child of current gene node -> we accept it as nextid
            next_gene_node = children[i];
          else //this is not the first non-loss child of current id -> we get out of the loop
          {
            donext = false;
            break;
          }
        }
      }
      //we write the event of the current node
      eventToPhyloXML(output, current_gene_node, associated_events, indent_level);
    }

    indent_level--;
    output << line_indentation(indent_level);
    output << closing_tag("eventsRec") << std::endl;


    //3. Sons, if any
    auto children = genetree.getSons(current_gene_node);

    for(unsigned i = 0 ; i < children.size(); i++)
    {
      nodeToRecPhyloXML(output, children.at(i), genetree, associated_events, indent_level);
    }

    indent_level--;
    output << line_indentation(indent_level);
    output << closing_tag("clade") << std::endl;
  }
}

/// Print a tree in PhyloXML format.
void OPhyloXML::nodeToPhyloXML(std::ostream &output, const bpp::PhyloTree &tree, Node node,
                               std::size_t indent_level) const {
  //cout << N->getInfos().postOrder << " " << N->getInfos().timeSlice << " " << N->getInfos().realPostOrder << " " << nodeid << endl;

  output << line_indentation(indent_level);
  output << opening_tag("clade") << std::endl;
  indent_level++;

  double distance = 0.0;
  double bootstrap = -1;

  Node current_node = node;

  if (tree.hasFather(current_node)){
    auto edgeToFather = tree.getEdgeToFather(current_node);
    if(edgeToFather->hasLength()){
      distance += tree.getEdgeToFather(current_node)->getLength();
    }

    if(edgeToFather->hasBootstrapValue()){
      bootstrap = edgeToFather->getBootstrapValue();
    }
  }

  auto children = tree.getSons(current_node);

  /*
  while(children.size() == 1)
  {
    current_node = children.front();
    children = tree.getSons(current_node);
    if (tree.hasFather(current_node) and tree.getEdgeToFather(current_node)->hasLength())
        distance += tree.getEdgeToFather(current_node)->getLength();
  }
   */

  node = current_node;

  //1. name:
  output << line_indentation(indent_level);
  output << opening_tag("name");
  if(tree.isLeaf(node)) //internal nodes actually have names that do not correspond to their RPO but the TS of the speciation
  {
    output << node->getName();
  }
  else
  {
    output << node->getName();
  }

  output << closing_tag("name") << std::endl;

  //2. distance to father and bootstrap
  if(not utils::double_equivalence(distance, 0.0))
  {
    output << line_indentation(indent_level) ;
    output << opening_tag("branch_length") << std::to_string(distance) << closing_tag("branch_length") << std::endl ;
  }

  if(not utils::double_equivalence(bootstrap, -1))
  {
    output << line_indentation(indent_level);
    output << opening_tag("confidence", "type", "\"bootstrap\"") << std::to_string(bootstrap) << closing_tag("confidence") << std::endl;
  }

  //3. id
  //output << line_indentation(indent_level) << std::endl;
  //output << "<node_id>" << N->getInfos().realPostOrder << "</node_id>\n";

  for(unsigned i = 0 ; i < children.size(); i++)
  {
    nodeToPhyloXML(output, tree, children.at(i), indent_level);
  }

  indent_level--;
  output << line_indentation(indent_level);
  output << closing_tag("clade") << std::endl;
}

void OPhyloXML::geneTreeToRecPhyloXML(std::ostream &output, const bpp::PhyloTree &tree, const int index, std::size_t indent_level) const {
  output << line_indentation(indent_level);
  output << opening_tag("recGeneTree") << std::endl;

  indent_level++;

  output << line_indentation(indent_level);
  output << opening_tag("phylogeny", "rooted", "\"true\"") << std::endl;

  indent_level++;

  if( index != -1)
  {
    output << line_indentation(indent_level);
    output << opening_tag("id") << index << closing_tag("id") << std::endl;
  }

  auto root = tree.getRoot();

  // Deduce gene events in the gene tree.
  auto nodes = PhyloTreeToolBox::getNodesInPostOrderTraversalIterative_list(tree);
  std::unordered_map<Node, Event> events;

  for(auto& node: nodes) {
    if(tree.isLeaf(node)){
      if(PhyloTreeToolBox::isArtificalGene(node)) {
        events[node] = loss;
      } else {
        events[node] = extant;
      }
    } else {
      auto sons = tree.getSons(node);
      auto& son_left = sons.front();
      auto& son_right = sons.back();
      assert(son_left->hasProperty("Species name"));
      assert(son_right->hasProperty("Species name"));

      bpp::BppString& son_left_species = *dynamic_cast<bpp::BppString*>(son_left->getProperty("Species name"));
      bpp::BppString& son_right_species = *dynamic_cast<bpp::BppString*>(son_right->getProperty("Species name"));

      if(son_left_species.toSTL() == son_right_species.toSTL()){
        events[node] = duplication;
      } else {
        if(events.at(son_left) == loss or events.at(son_right) == loss){
          events[node] = speciationLoss;
        } else {
          events[node] = speciation;
        }
      }
    }
  }

  nodeToRecPhyloXML(output, root, tree, events, indent_level);


  indent_level--;
  output << line_indentation(indent_level);
  output << closing_tag("phylogeny") << std::endl;

  indent_level--;
  output << line_indentation(indent_level);

  output << closing_tag("recGeneTree") << std::endl;

}

void OPhyloXML::phylogenyToPhyloXML_(std::ostream &output, const bpp::PhyloTree &tree, const std::string &description,
                                     std::size_t indent_level) const {
  output << line_indentation(indent_level);
  if(tree.isRooted())
    output << opening_tag("phylogeny", "rooted", "\"true\"") << std::endl;
  else
    output << opening_tag("phylogeny", "rooted", "\"false\"") << std::endl;

  if(not description.empty())
    output << line_indentation(indent_level) << opening_tag("description") << description << closing_tag("description") << std::endl;

  indent_level++;
  auto root = tree.getRoot();
  nodeToPhyloXML(output, tree, root, indent_level);

  indent_level--;
  output << line_indentation(indent_level);
  output << closing_tag("phylogeny") << std::endl;
}

void OPhyloXML::speciesTreeToPhyloXML(std::ostream& output, const bpp::PhyloTree& speciestree, std::size_t indent_level) const {
  output << line_indentation(indent_level);
  output << opening_tag("spTree") << std::endl;

  indent_level++;
  phylogenyToPhyloXML_(output, speciestree, "", indent_level);

  indent_level--;
  output << line_indentation(indent_level);
  output << closing_tag("spTree") << std::endl;
}

void OPhyloXML::treeToPhyloXML(std::ostream& output, const bpp::PhyloTree& tree, const std::string& description, std::size_t indent_level) const {
  output << line_indentation(indent_level);
  output << opening_tag("phyloxml") << std::endl;

  indent_level++;
  phylogenyToPhyloXML_(output, tree, description, indent_level);

  indent_level--;
  output << line_indentation(indent_level);
  output << closing_tag("phyloxml") << std::endl;
}

void OPhyloXML::write(const bpp::PhyloTree &tree, std::ostream &out) const {
  treeToPhyloXML(out, tree);
}

void OPhyloXML::write(const std::vector<const bpp::PhyloTree *> &trees, std::ostream &out) const {
  std::size_t indent_level = 0;
  out << line_indentation(indent_level);
  out << opening_tag("phyloxml") << std::endl;

  for(auto tree: trees) {
    indent_level++;
    phylogenyToPhyloXML_(out, *tree, "", indent_level);
    indent_level--;
  }

  out << line_indentation(indent_level);
  out << closing_tag("phyloxml") << std::endl;
}

} // namespace treerecs

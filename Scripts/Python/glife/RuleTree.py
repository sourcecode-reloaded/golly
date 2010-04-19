import golly

# This file contains two ways of building rule trees:
#
# 1) Usage example:
#
# tree = RuleTree(14,4) # 14 states, 4 neighbors = von Neumann neighborhood
# tree.add_rule([[1],[1,2,3],[3],[0,1],[2]],7) # inputs: [C,S,E,W,N], ouput
# tree.write("test.tree")
#
# 2) Usage example:
#
# MakeRuleTreeFromTransitionFunction( 2, 4, lambda a:(a[0]+a[1]+a[2])%2, 'parity.tree' )

class RuleTree:
    '''
    Usage example:
    
    tree = RuleTree(14,4) # 14 states, 4 neighbors = von Neumann neighborhood
    tree.add_rule([[1],[1,2,3],[3],[0,1],[2]],7) # inputs: [C,S,E,W,N], ouput
    tree.write("test.tree")
    '''

    def __init__(self,numStates,numNeighbors):
    
        self.numParams = numNeighbors + 1 ;
        self.world = {} # dictionary mapping node string to node index
        # (nodes would be better stored as an int list but these aren't hashable)
        self.seq = [] # same node strings but stored in a list
        self.params = {}
        self.nodeSeq = 0
        self.curndd = -1
        self.numStates = numStates
        self.numNeighbors = numNeighbors
        
        self.cache = {}
        self.shrinksize = 100
        
        self._init_tree()
        
    def _init_tree(self):
        self.curndd = -1
        for i in range(self.numParams):
          node = str(i+1)
          for j in range(self.numStates):
             node += " " + str(self.curndd)
          self.curndd = self._getNode(node)

    def _getNode(self,node_string):
        if node_string in self.world:
            return self.world[node_string]
        else:
            new_node = self.nodeSeq
            self.nodeSeq += 1
            self.seq.append(node_string)
            self.world[node_string] = new_node
            return new_node
            
    def _add(self,inputs,output,nddr,at):
        if at == 0: # this is a leaf node
            if nddr<0:
                return output # return the output of the transition
            else:
                return nddr # return the node index
        if nddr in self.cache:
            return self.cache[nddr]
        node = map(int,self.seq[nddr].split()[1:]) # convert node string to list, skip depth
        inset = inputs[at-1] # inset is a list of the permissable values for this input
        for value in inset:
            if value<0 or value>=self.numStates:
                golly.warn("Input out of range for: "+str(inputs))
                golly.exit()
            node[value] = self._add(inputs, output, node[value], at-1)
        node_string = str(at) + " " + " ".join(map(str,node))
        r = self._getNode(node_string)
        self.cache[nddr] = r
        return r
            
    def _recreate(self,oseq,nddr,lev):
        if lev == 0:
            return nddr
        if nddr in self.cache:
            return self.cache[nddr]
        node = map(int,oseq[nddr].split()[1:]) # convert node string to list, skip depth
        for i,value in enumerate(node):
            node[i] = self._recreate(oseq, value, lev-1)
        node_string = str(lev) + " " + " ".join(map(str,node))
        r = self._getNode(node_string)
        self.cache[nddr] = r
        return r

    def _shrink(self):
        self.world = {}
        oseq = self.seq
        self.seq = []
        self.cache = {}
        self.nodeSeq = 0 ;
        self.curndd = self._recreate(oseq, self.curndd, self.numParams)
        #golly.show("Shrunk from " + str(len(oseq)) + " to " + str(len(self.seq)) + "\n")
        self.shrinksize = len(self.seq) * 2

    def add_rule(self,inputs,output):
        if not len(inputs)==self.numParams:
            golly.warn("Input length mismatch: "+str(inputs))
            golly.exit()
        self.cache = {}
        self.curndd = self._add(inputs,output,self.curndd,self.numParams)
        if self.nodeSeq > self.shrinksize:
            self._shrink()
            
    def _setdefaults(self,nddr,off,at):
        if at == 0:
            if nddr<0:
                return off
            else:
                return nddr
        if nddr in self.cache:
            return self.cache[nddr]
        node = map(int,self.seq[nddr].split()[1:]) # convert node string to list, skip depth
        for i,value in enumerate(node):
            node[i] = self._setdefaults(value, i, at-1)
        node_string = str(at) + " " + " ".join(map(str,node))
        node_index = self._getNode(node_string)
        self.cache[nddr] = node_index
        return node_index

    def _setDefaults(self):
        self.cache = {}
        self.curndd = self._setdefaults(self.curndd, -1, self.numParams)
      
    def write(self,filename):
        self._setDefaults()
        self._shrink()
        out = open(filename,'w')
        out.write("num_states=" + str(self.numStates)+'\n')
        out.write("num_neighbors=" + str(self.numNeighbors)+'\n')
        out.write("num_nodes=" + str(len(self.seq))+'\n')
        for rule in self.seq:
            out.write(rule+'\n')
        out.flush()
        out.close()

class MakeRuleTreeFromTransitionFunction:
    '''
    Usage example:

    MakeRuleTreeFromTransitionFunction( 2, 4, lambda a:(a[0]+a[1]+a[2])%2, 'parity.tree' )
    '''
        
    def __init__(self,numStates,numNeighbors,f,filename):
        self.numParams = numNeighbors + 1 ;
        self.numStates = numStates
        self.numNeighbors = numNeighbors
        self.world = {}
        self.seq = []
        self.params = {}
        self.nodeSeq = 0
        self.f = f
        self._recur(self.numParams)
        self._write(filename)

    def _getNode(self,node_string):
        if node_string in self.world:
            return self.world[node_string]
        else:
            new_node = self.nodeSeq
            self.nodeSeq += 1
            self.seq.append(node_string)
            self.world[node_string] = new_node
            return new_node
            
    def _recur(self,at):
        if at == 0:
            return self.f(self.params)
        n = str(at)
        for i in range(self.numStates):
            self.params[self.numParams-at] = i
            n += " " + str(self._recur(at-1))
        return self._getNode(n)

    def _write(self,filename):
        out = open(filename,'w')
        out.write("num_states=" + str(self.numStates)+'\n')
        out.write("num_neighbors=" + str(self.numNeighbors)+'\n')
        out.write("num_nodes=" + str(len(self.seq))+'\n')
        for rule in self.seq:
            out.write(rule+'\n')
        out.flush()
        out.close()
        

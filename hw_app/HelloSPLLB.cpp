// Copyright (c) 2007-2015, Intel Corporation
//
// Redistribution  and  use  in source  and  binary  forms,  with  or  without
// modification, are permitted provided that the following conditions are met:
//
// * Redistributions of  source code  must retain the  above copyright notice,
//   this list of conditions and the following disclaimer.
// * Redistributions in binary form must reproduce the above copyright notice,
//   this list of conditions and the following disclaimer in the documentation
//   and/or other materials provided with the distribution.
// * Neither the name  of Intel Corporation  nor the names of its contributors
//   may be used to  endorse or promote  products derived  from this  software
//   without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING,  BUT NOT LIMITED TO,  THE
// IMPLIED WARRANTIES OF  MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED.  IN NO EVENT  SHALL THE COPYRIGHT OWNER  OR CONTRIBUTORS BE
// LIABLE  FOR  ANY  DIRECT,  INDIRECT,  INCIDENTAL,  SPECIAL,  EXEMPLARY,  OR
// CONSEQUENTIAL  DAMAGES  (INCLUDING,  BUT  NOT LIMITED  TO,  PROCUREMENT  OF
// SUBSTITUTE GOODS OR SERVICES;  LOSS OF USE,  DATA, OR PROFITS;  OR BUSINESS
// INTERRUPTION)  HOWEVER CAUSED  AND ON ANY THEORY  OF LIABILITY,  WHETHER IN
// CONTRACT,  STRICT LIABILITY,  OR TORT  (INCLUDING NEGLIGENCE  OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,  EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.
//****************************************************************************
/// @file HelloSPLLB.cpp
/// @brief Basic SPL AFU interaction.
/// @ingroup HelloSPLLB
/// @verbatim
/// Intel(R) QuickAssist Technology Accelerator Abstraction Layer Sample Application
///
///    This application is for example purposes only.
///    It is not intended to represent a model for developing commercially-deployable applications.
///    It is designed to show working examples of the AAL programming model and APIs.
///
/// AUTHORS: Joseph Grecco, Intel Corporation.
///
/// This Sample demonstrates the following:
///    - The basic structure of an AAL program using the AAL Runtime APIs.
///    - The ISPLAFU and ISPLClient interfaces of the SPLAFU Service.
///    - System initialization and shutdown.
///    - Use of interface IDs (iids).
///    - Accessing object interfaces through the Interface functions.
///
/// This sample is designed to be used with the SPLAFU Service.
///
/// HISTORY:
/// WHEN:          WHO:     WHAT:
/// 06/15/2015     JG       Initial version started based on older sample code.@endverbatim
//****************************************************************************
#include <aalsdk/AAL.h>
#include <aalsdk/xlRuntime.h>
#include <aalsdk/AALLoggerExtern.h> // Logger


#include <aalsdk/service/ISPLAFU.h>       // Service Interface
#include <aalsdk/service/ISPLClient.h>    // Service Client Interface
#include <aalsdk/kernel/vafu2defs.h>      // AFU structure definitions (brings in spl2defs.h)

#include <string.h>
#include <ctime>
#include <time.h>
#include <sys/time.h>
#include <stdlib.h>
#include <vector>
#include <algorithm>
#include <iterator>
#include <fstream>
#include <iostream>

#include <omp.h>
#include <stdio.h>

//****************************************************************************
// UN-COMMENT appropriate #define in order to enable either Hardware or ASE.
//    DEFAULT is to use Software Simulation.
//****************************************************************************
#define  HWAFU
//#define  ASEAFU

using namespace AAL;

// Convenience macros for printing messages and errors.
#ifdef MSG
# undef MSG
#endif // MSG
#define MSG(x) std::cout << __AAL_SHORT_FILE__ << ':' << __LINE__ << ':' << __AAL_FUNC__ << "() : " << x << std::endl
#ifdef ERR
# undef ERR
#endif // ERR
#define ERR(x) std::cerr << __AAL_SHORT_FILE__ << ':' << __LINE__ << ':' << __AAL_FUNC__ << "() **Error : " << x << std::endl

// Print/don't print the event ID's entered in the event handlers.
#if 1
# define EVENT_CASE(x) case x : MSG(#x);
#else
# define EVENT_CASE(x) case x :
#endif

#ifndef CL
# define CL(x)                     ((x) * 64)
#endif // CL
#ifndef LOG2_CL
# define LOG2_CL                   6
#endif // LOG2_CL
#ifndef MB
# define MB(x)                     ((x) * 1024 * 1024)
#endif // MB
#define LPBK1_BUFFER_SIZE        CL(1)

#define LPBK1_DSM_SIZE           MB(4)

// self-defined macro
#define num_KB                  4    // number of KBytes of data to be sorted
#define num_MB                  512     // number of MB to be sorted by HW
#define timeout                 10    // wait for number of seconds to timeout
#define sleep_interval          10    // check every 100 ms
#define block_size              1024    // number of cacheline per block or number of tasks per block
#define num_threads             16

#define num_setgroup            16384
#define num_set                 2
#define num_setSize             8
#define tree_depth              14

typedef unsigned short int bt16bitInt;

/// @addtogroup HelloSPLLB
/// @{

/// @brief   Define our Runtime client class so that we can receive the runtime started/stopped notifications.
///
/// We implement a Service client within, to handle AAL Service allocation/free.
/// We also implement a Semaphore for synchronization with the AAL runtime.

static int rand_x = 200, rand_y = 50, rand_z = 3000;

static int 
random_function() {
    rand_x = ( rand_x * 171 ) % 30269;
    rand_y = ( rand_y * 172 ) % 30307;
    rand_z = ( rand_z * 170 ) % 30323;
    float n = ((((float)rand_x)/30269.0) + (((float)rand_y)/30307.0) + (((float)rand_z)/30323.0)) * 100;
    return n;
}


class RuntimeClient : public CAASBase,
                      public IRuntimeClient
{
public:
   RuntimeClient();
   ~RuntimeClient();

   void end();

   IRuntime* getRuntime();

   btBool isOK();

   // <begin IRuntimeClient interface>
   void runtimeStarted(IRuntime            *pRuntime,
                       const NamedValueSet &rConfigParms);

   void runtimeStopped(IRuntime *pRuntime);

   void runtimeStartFailed(const IEvent &rEvent);

   void runtimeAllocateServiceFailed( IEvent const &rEvent);

   void runtimeAllocateServiceSucceeded(IBase               *pClient,
                                        TransactionID const &rTranID);

   void runtimeEvent(const IEvent &rEvent);
   // <end IRuntimeClient interface>

protected:
   IRuntime        *m_pRuntime;  ///< Pointer to AAL runtime instance.
   Runtime          m_Runtime;   ///< AAL Runtime
   btBool           m_isOK;      ///< Status
   CSemaphore       m_Sem;       ///< For synchronizing with the AAL runtime.
};

///////////////////////////////////////////////////////////////////////////////
///
///  MyRuntimeClient Implementation
///
///////////////////////////////////////////////////////////////////////////////
RuntimeClient::RuntimeClient() :
    m_Runtime(),        // Instantiate the AAL Runtime
    m_pRuntime(NULL),
    m_isOK(false)
{
   NamedValueSet configArgs;
   NamedValueSet configRecord;

   // Publish our interface
   SetSubClassInterface(iidRuntimeClient, dynamic_cast<IRuntimeClient *>(this));

   m_Sem.Create(0, 1);

   // Using Hardware Services requires the Remote Resource Manager Broker Service
   //  Note that this could also be accomplished by setting the environment variable
   //   XLRUNTIME_CONFIG_BROKER_SERVICE to librrmbroker
#if defined( HWAFU )
   configRecord.Add(XLRUNTIME_CONFIG_BROKER_SERVICE, "librrmbroker");
   configArgs.Add(XLRUNTIME_CONFIG_RECORD,configRecord);
#endif

   if(!m_Runtime.start(this, configArgs)){
      m_isOK = false;
      return;
   }
   m_Sem.Wait();
}

RuntimeClient::~RuntimeClient()
{
    m_Sem.Destroy();
}

btBool RuntimeClient::isOK()
{
   return m_isOK;
}

void RuntimeClient::runtimeStarted(IRuntime *pRuntime,
                                   const NamedValueSet &rConfigParms)
{
   // Save a copy of our runtime interface instance.
   m_pRuntime = pRuntime;
   m_isOK = true;
   m_Sem.Post(1);
}

void RuntimeClient::end()
{
   m_Runtime.stop();
   m_Sem.Wait();
}

void RuntimeClient::runtimeStopped(IRuntime *pRuntime)
{
   MSG("Runtime stopped");
   m_isOK = false;
   m_Sem.Post(1);
}

void RuntimeClient::runtimeStartFailed(const IEvent &rEvent)
{
   IExceptionTransactionEvent * pExEvent = dynamic_ptr<IExceptionTransactionEvent>(iidExTranEvent, rEvent);
   ERR("Runtime start failed");
   ERR(pExEvent->Description());
}

void RuntimeClient::runtimeAllocateServiceFailed( IEvent const &rEvent)
{
   IExceptionTransactionEvent * pExEvent = dynamic_ptr<IExceptionTransactionEvent>(iidExTranEvent, rEvent);
   ERR("Runtime AllocateService failed");
   ERR(pExEvent->Description());
}

void RuntimeClient::runtimeAllocateServiceSucceeded(IBase *pClient,
                                                    TransactionID const &rTranID)
{
   MSG("Runtime Allocate Service Succeeded");
}

void RuntimeClient::runtimeEvent(const IEvent &rEvent)
{
   MSG("Generic message handler (runtime)");
}

IRuntime * RuntimeClient::getRuntime()
{
   return m_pRuntime;
}


/// @brief   Define our Service client class so that we can receive Service-related notifications from the AAL Runtime.
///          The Service Client contains the application logic.
///
/// When we request an AFU (Service) from AAL, the request will be fulfilled by calling into this interface.
class HelloSPLLBApp: public CAASBase, public IServiceClient, public ISPLClient
{
public:

   HelloSPLLBApp(RuntimeClient * rtc);
   ~HelloSPLLBApp();

   btInt run();
   void Show2CLs(void *pCLExpected,
                 void *pCLFound,
                 ostringstream &oss);
   void _DumpCL(void *pCL,
                ostringstream &oss);

   // self defined application method
   void merge_hardware(btUnsigned32bitInt *pDestInt, btUnsignedInt length);

   bt16bitInt merge_software(std::vector<bt16bitInt> setGroupIdx);

   bt16bitInt lookup(bt16bitInt keyIn, bool idxIn);

   void setIntersec16func(int numSetGroup, int numSet, bt16bitInt ** setData, 
				          bt16bitInt * idx, bt16bitInt * result);
				  
   void setIntersec16par(int numSetGroup, int numSet, bt16bitInt ** setData, 
				   bt16bitInt ** idxOutGroup, bt16bitInt * result, int threadCount);
				   
   void setIntersec16serial(int numSetGroup, 
                   int numSet, int numTasks, bt16bitInt ** setData, 
				   bt16bitInt ** idx, bt16bitInt * result);
				   
   timespec calculate_time_interval(timespec late, timespec early);

   // <ISPLClient>
   virtual void OnTransactionStarted(TransactionID const &TranID,
                                     btVirtAddr AFUDSM,
                                     btWSSize AFUDSMSize);
   virtual void OnContextWorkspaceSet(TransactionID const &TranID);

   virtual void OnTransactionFailed(const IEvent &Event);

   virtual void OnTransactionComplete(TransactionID const &TranID);

   virtual void OnTransactionStopped(TransactionID const &TranID);
   virtual void OnWorkspaceAllocated(TransactionID const &TranID,
                                     btVirtAddr WkspcVirt,
                                     btPhysAddr WkspcPhys,
                                     btWSSize WkspcSize);

   virtual void OnWorkspaceAllocateFailed(const IEvent &Event);

   virtual void OnWorkspaceFreed(TransactionID const &TranID);

   virtual void OnWorkspaceFreeFailed(const IEvent &Event);
   // </ISPLClient>

   // <begin IServiceClient interface>
   virtual void serviceAllocated(IBase *pServiceBase,
                                 TransactionID const &rTranID);

   virtual void serviceAllocateFailed(const IEvent &rEvent);

   virtual void serviceFreed(TransactionID const &rTranID);

   virtual void serviceEvent(const IEvent &rEvent);
   // <end IServiceClient interface>

protected:
   IBase         *m_pAALService;    // The generic AAL Service interface for the AFU.
   RuntimeClient *m_runtimClient;
   ISPLAFU       *m_SPLService;
   CSemaphore     m_Sem;            // For synchronizing with the AAL runtime.
   btInt          m_Result;

   // Workspace info
   btVirtAddr     m_pWkspcVirt;     ///< Workspace virtual address.
   btWSSize       m_WkspcSize;      ///< DSM workspace size in bytes.

   btVirtAddr     m_AFUDSMVirt;     ///< Points to DSM
   btWSSize       m_AFUDSMSize;     ///< Length in bytes of DSM


  bt16bitInt ** setData;

  bt16bitInt ** keyData;
};

///////////////////////////////////////////////////////////////////////////////
///
///  Implementation
///
///////////////////////////////////////////////////////////////////////////////
HelloSPLLBApp::HelloSPLLBApp(RuntimeClient *rtc) :
   m_pAALService(NULL),
   m_runtimClient(rtc),
   m_SPLService(NULL),
   m_Result(0),
   m_pWkspcVirt(NULL),
   m_WkspcSize(0),
   m_AFUDSMVirt(NULL),
   m_AFUDSMSize(0)
{
   SetSubClassInterface(iidServiceClient, dynamic_cast<IServiceClient *>(this));
   SetInterface(iidSPLClient, dynamic_cast<ISPLClient *>(this));
   SetInterface(iidCCIClient, dynamic_cast<ICCIClient *>(this));
   m_Sem.Create(0, 1);

   // const int num_setgroup = 4;
   // const int num_set = 16;
   // const int num_setSize = 32*1024; //32K
   //Initialize setData
   const int max_num = 1<<5-1;  
   
   setData  = new bt16bitInt * [num_setgroup*num_set];  //
   for(int i = 0; i < num_setgroup*num_set; i++) {
        setData[i] = new bt16bitInt[num_setSize];
    }
   
   //std::srand((uint)std::time(0));
   for(int i = 0; i < num_setgroup*num_set; i++)
	   for(int k = 0; k < num_setSize; k++)
	   {
		   setData[i][k] = (bt16bitInt)(random_function() % max_num);
	   }


    for(int i = 0; i < num_setgroup*num_set; i++)
	    //std::sort(setData[i], num_setSize, sizeof(bt16bitInt), compareUint);
		std::sort(setData[i], setData[i]+num_setSize);
	
	//Initialize keyData
	// char ram_init_data[] = "tree_data_0";
	//std::string infileName = "tree_data_0";

    keyData  = new bt16bitInt * [tree_depth];  //
    for(int i = 0; i < tree_depth; i++) {
        keyData[i] = new bt16bitInt[1<<tree_depth];
     }
   
    //std::srand((uint)std::time(0));
    for(int i = 0; i < tree_depth; i++)
	   for(int k = 0; k < (1<<tree_depth); k++)
	   {
		   keyData[i][k] = (bt16bitInt)(random_function() % max_num);
	   }


}

HelloSPLLBApp::~HelloSPLLBApp()
{
   m_Sem.Destroy();
   for(int i = 0; i < num_setgroup*num_set; ++i) {
        delete [] setData[i];
    }
    delete [] setData;
	
	 for(int i = 0; i < tree_depth; ++i) {
        delete [] keyData[i];
    }
    delete [] keyData;

}

void HelloSPLLBApp::merge_hardware(btUnsigned32bitInt *pDestInt
                                                    , btUnsigned32bitInt length)
{
    //btUnsigned32bitInt *next_block = pDestInt + length;    // point to the next block
    //// make a copy of the first block
    //btUnsigned32bitInt *cacheline_temp = new btUnsigned32bitInt[length];
    //for (btUnsignedInt i = 0; i < length; i++) {
    //    cacheline_temp[i] = pDestInt[i];
    //}
    //int i = 0; // index of final array
    //int j = 0;  // index of memory block
    //int k = 0;          // index of temp cacheline
    //while ((j < length) && (k < length)) {
    //    while ((j < length) && (next_block[j] < cacheline_temp[k])) {
    //        pDestInt[i] = next_block[j];
    //        i += 1;
    //        j += 1;
    //    }
    //    while ((k < length) && (next_block[j] >= cacheline_temp[k])) {
    //        pDestInt[i] = cacheline_temp[k];
    //        i += 1;
    //        k += 1;
    //    }
    //}
    //while (k < length) {
    //    pDestInt[i] = cacheline_temp[k];
    //    i += 1;
    //    k += 1;
    //}
    //delete [] cacheline_temp;
	std::vector<bt16bitInt> setGroupIdx;
	bt16bitInt intersec;
	
	for(int i = 0; i < block_size; i++)
	{
		//for(int j = 0; j < 2; j++){
		for(int k = 0; k < num_set; k++){
		    bt16bitInt setIdx = ((bt16bitInt)(*(pDestInt 
		                                   // + (curr_block - 1) * 32 * block_size    //one block 16 cache lines
		 								   + i*16          // one cl 32 16-bit data
		 								   //+ j*num_set   // one cl two set groups
							               + k
		 								   )));
		   setGroupIdx.push_back(setIdx);
           }
		   
		   intersec = merge_software(setGroupIdx);
	}
	
	
	//std::vector<std::vector<bt16bitInt> > intersecGroup;  
}



bt16bitInt HelloSPLLBApp::merge_software(std::vector<bt16bitInt> setGroupIdx)
{
   	//std::vector<std::vector<bt16bitInt> > intersecGroup;  
	
	//MSG("STEP1");
	//ASSERT(setGroupIdx < num_setgroup);
	unsigned int * idx = new unsigned int [num_set];
	bt16bitInt ** setData_tmp = new bt16bitInt* [num_set];
	
	for(int i=0; i<num_set; i++)
	{
		idx[i] = 0;
	}	
		
	for(int i = 0; i < num_set; i++) {
        setData_tmp[i] = new bt16bitInt[num_setSize];
    }
	
   for(int i = 0; i < num_set; i++)
	   for(int k = 0; k < num_setSize; k++)
	   {
		   //bt16bitInt setIdx = setGroupIdx[i] % (1<<tree_depth);	
           bt16bitInt setIdx = setGroupIdx[i] % num_setgroup;	 		   
		   setData_tmp[i][k] = setData[setIdx+i*num_setgroup][k];
	   }
	   
	bool finished = 0;
	bool findsec = 0;
	
	while(!finished && !findsec)
	{
		finished = 1;
		for(int i=0; i<num_set; i++)
	    {
		    finished &= (idx[i] >= num_setSize - 1);
	    }	
		
		//MSG("STEP2");
		bt16bitInt max = setData_tmp[0][idx[0]];
		bt16bitInt max_idx = 0;
		
		findsec = 1;
		for(int i=1; i<num_set; i++)
		{
			if(setData_tmp[i][idx[i]] > max )
			{
				idx[max_idx]++;
				max = setData_tmp[i][idx[i]];
				max_idx = i;
				findsec = 0;
			}else if(setData_tmp[i][idx[i]] == max )	
            {
				max = setData_tmp[i][idx[i]];
				max_idx = i;
			}else
			{
				idx[i]++;
				findsec = 0;
			}				
		}
		
		if(findsec)
		{
			return max;
		}
		
	}	
    
	delete [] idx;
	
	for(int i = 0; i < num_set; ++i) {
        delete [] setData_tmp[i];
    }
    delete [] setData_tmp;
	
	return 1;
}





void HelloSPLLBApp::setIntersec16func(int numSetGroup, 
                   int numSet,
                   bt16bitInt ** setData, 
				   bt16bitInt * idx,
				   bt16bitInt * result)
{
	bool finished = 0;
	bool findsec = 0;
	int i = 0;
	int j = 0;
	int k = 0;
	bt16bitInt max;
	bt16bitInt max_idx;	

	/*for(i = 0; i < num_set; i++){
	   for(k = 0; k < num_setSize; k++)
	   {
		  std::cout<<setData[i][k]<<" ";
	   }
	   std::cout<<std::endl;
	}*/
	
	while(!finished && !findsec)
	{
		finished = 0;
		for(int i=0; i<num_set; i++)
	    {
		    finished = (finished | (idx[i] >= num_setSize-1));
	    }	
		
		//MSG("STEP2");
		bt16bitInt max = setData[0][idx[0]];
		bt16bitInt max_idx = 0;
		
		findsec = 1;
		for(int i=1; i<num_set; i++)
		{
			if(setData[i][idx[i]] > max )
			{
				idx[max_idx]++;
				max = setData[i][idx[i]];
				max_idx = i;
				findsec = 0;
			}else if(setData[i][idx[i]] == max )	
            {
				max = setData[i][idx[i]];
				max_idx = i;
			}else
			{
				idx[i]++;
				findsec = 0;
			}				
		}
		
		if(findsec)
		{
			result[0] = max;
			return;
		}
		
	}	
  
}


void HelloSPLLBApp::setIntersec16par(int numSetGroup, 
                   int numSet,
                   bt16bitInt ** setData, 
				   bt16bitInt ** idxOutGroup,
				   bt16bitInt * result,
				   int threadCount)
{
    int tid, nthreads;
	int i = 0;
	int j = 0;
	int k = 0;
	bt16bitInt ** setData_tmp;	
	bt16bitInt * idx_tmp;
	
	omp_set_dynamic(0);
	omp_set_num_threads(threadCount); 
    #pragma omp parallel shared(numSetGroup, numSet, setData, idxOutGroup,   \
                                result, nthreads) \
                        private(i, j, k, tid, setData_tmp, idx_tmp)
	{
		tid = omp_get_thread_num();
        nthreads = omp_get_num_threads();
	    //if(tid == 0)
        //    std::cout<<"Num of threads"<<nthreads<<std::endl;
		
		setData_tmp = new bt16bitInt* [num_set];
		idx_tmp = new bt16bitInt [num_set];
		
	    for(j = 0; j < num_set; j++) {
            setData_tmp[j] = new bt16bitInt[num_setSize];
        }
				
		for(j = 0; j<num_set; j++)
	    {
		    idx_tmp[j] = 0;
	    }		    
		
        for(j = 0; j < num_set; j++)
	      for(k = 0; k < num_setSize; k++)
	    {   
	       bt16bitInt idxOut = idxOutGroup[tid][j] % num_setgroup;
		   //setData_tmp[j][k] = setData[idxOut+j*num_setgroup][k];
		   
		   //TEST1
		   setData_tmp[j][k] = setData[idxOut+0*num_setgroup][k];
	    }
	   
	   setIntersec16func(num_setgroup,num_set,setData_tmp,idx_tmp,result+tid);	   
	   
	   delete [] idx_tmp;  
	   
	   for(int j = 0; j < num_set; ++j) {
          delete [] setData_tmp[j];
       }
	   delete [] setData_tmp;
	}	
}



void HelloSPLLBApp::setIntersec16serial(int numSetGroup, 
                   int numSet,
				   int numTasks,
                   bt16bitInt ** setData, 
				   bt16bitInt ** idx,
				   bt16bitInt * result)
{
	for(int i = 0; i < numTasks; i++)
	{
		bt16bitInt ** setData_tmp = new bt16bitInt* [num_set];	
	    for(int j = 0; j < num_set; j++) {
            setData_tmp[j] = new bt16bitInt[num_setSize];
        }
		bt16bitInt * idx_tmp = new bt16bitInt [num_set];
		
		for(int j = 0; j<num_set; j++)
	    {
		   // idx_tmp[j] = idx[i][j];
		    idx_tmp[j] = 0;
	    }		    
		
       for(int j = 0; j < num_set; j++)
	      for(int k = 0; k < num_setSize; k++)
	   {
		   //bt16bitInt setIdx = setGroupIdx[i] % (1<<tree_depth);	
           bt16bitInt idxOut_tmp = 	idx[i][j] % num_setgroup;	   
		   setData_tmp[j][k] = setData[idxOut_tmp+j*num_setgroup][k];
	   }
	   
	   setIntersec16func(num_setgroup,num_set,setData_tmp,idx_tmp,result+i);	   
	   
	   delete [] idx_tmp;  
	   
	   for(int j = 0; j < num_set; ++j) {
          delete [] setData_tmp[j];
       }
	   delete [] setData_tmp;
	}
}


bt16bitInt HelloSPLLBApp::lookup(bt16bitInt keyIn, bool idxIn)
{
	bt16bitInt keyIntmp, idxIntmp, dataOutTmp, idxOutTmp;
	keyIntmp = keyIn;
	idxIntmp = (bt16bitInt)idxIn;
	//MSG("STEP11");
	//MSG(keyIntmp);
	//MSG(idxIntmp);
	
	for(int i=0; i<tree_depth; i++)	
	{
		bt16bitInt dataOut = keyData[i][idxIntmp];
		idxOutTmp = (keyIntmp < dataOut) ? idxIntmp*2+1: idxIntmp*2+2;
		idxIntmp = idxOutTmp;
	}
	return idxOutTmp;
}

// used as function pointer
int compareUint(const void *a, const void *b) {
    if (*(unsigned int*)a < *(unsigned int*)b) {
        return -1;
    } else if (*(unsigned int*)a == *(unsigned int*)b) {
        return 0;
    } else {
        return 1;
    }
}


timespec HelloSPLLBApp::calculate_time_interval(timespec late, timespec early)
{
    timespec time_difference;
    if (late.tv_nsec < early.tv_nsec) {
        time_difference.tv_sec = late.tv_sec - early.tv_sec - 1;
        time_difference.tv_nsec = late.tv_nsec - early.tv_nsec + 1000000000;
    } else {
        time_difference.tv_sec = late.tv_sec - early.tv_sec;
        time_difference.tv_nsec = late.tv_nsec - early.tv_nsec;
    }
    return time_difference;
}


btInt HelloSPLLBApp::run()
{
   cout <<"======================="<<endl;
   cout <<"= Hello SPL LB Sample ="<<endl;
   cout <<"======================="<<endl;


   // Request our AFU.

   // NOTE: This example is bypassing the Resource Manager's configuration record lookup
   //  mechanism.  This code is work around code and subject to change.
   NamedValueSet Manifest;
   NamedValueSet ConfigRecord;


#if defined( HWAFU )                /* Use FPGA hardware */
   ConfigRecord.Add(AAL_FACTORY_CREATE_CONFIGRECORD_FULL_SERVICE_NAME, "libHWSPLAFU");
   ConfigRecord.Add(keyRegAFU_ID,"00000000-0000-0000-0000-000011100181");
   ConfigRecord.Add(AAL_FACTORY_CREATE_CONFIGRECORD_FULL_AIA_NAME, "libAASUAIA");

   #elif defined ( ASEAFU )
   ConfigRecord.Add(AAL_FACTORY_CREATE_CONFIGRECORD_FULL_SERVICE_NAME, "libASESPLAFU");
   ConfigRecord.Add(AAL_FACTORY_CREATE_SOFTWARE_SERVICE,true);

#else

   ConfigRecord.Add(AAL_FACTORY_CREATE_CONFIGRECORD_FULL_SERVICE_NAME, "libSWSimSPLAFU");
   ConfigRecord.Add(AAL_FACTORY_CREATE_SOFTWARE_SERVICE,true);
#endif

   Manifest.Add(AAL_FACTORY_CREATE_CONFIGRECORD_INCLUDED, ConfigRecord);

   Manifest.Add(AAL_FACTORY_CREATE_SERVICENAME, "Hello SPL LB");

   MSG("Allocating Service");

   // Allocate the Service and allocate the required workspace.
   //   This happens in the background via callbacks (simple state machine).
   //   When everything is set we do the real work here in the main thread.
   m_runtimClient->getRuntime()->allocService(dynamic_cast<IBase *>(this), Manifest);

   m_Sem.Wait();

   // If all went well run test.
   //   NOTE: If not successful we simply bail.
   //         A better design would do all appropriate clean-up.
   if(0 == m_Result){


      //=============================
      // Now we have the NLB Service
      //   now we can use it
      //=============================
      MSG("Running Test");

      btVirtAddr         pWSUsrVirt = m_pWkspcVirt; // Address of Workspace
      const btWSSize     WSLen      = m_WkspcSize; // Length of workspace

      MSG("Allocated " << WSLen << "-byte Workspace at virtual address "
                       << std::hex << (void *)pWSUsrVirt);

      // Number of bytes in each of the source and destination buffers (4 MiB in this case)
      btUnsigned32bitInt a_num_bytes= (btUnsigned32bitInt) ((WSLen - sizeof(VAFU2_CNTXT)) / 2);
      btUnsigned32bitInt a_num_cl   = a_num_bytes / CL(1);  // number of cache lines in buffer

      // VAFU Context is at the beginning of the buffer
      VAFU2_CNTXT       *pVAFU2_cntxt = reinterpret_cast<VAFU2_CNTXT *>(pWSUsrVirt);

      // The source buffer is right after the VAFU Context
      btVirtAddr         pSource = pWSUsrVirt + sizeof(VAFU2_CNTXT);

      // The destination buffer is right after the source buffer
      btVirtAddr         pDest   = pSource + a_num_bytes;

      struct OneCL {                      // Make a cache-line sized structure
         btUnsigned32bitInt dw[16];       //    for array arithmetic
      };
      struct OneCL      *pSourceCL = reinterpret_cast<struct OneCL *>(pSource);
      struct OneCL      *pDestCL   = reinterpret_cast<struct OneCL *>(pDest);

      // Note: the usage of the VAFU2_CNTXT structure here is specific to the underlying bitstream
      // implementation. The bitstream targeted for use with this sample application must implement
      // the Validation AFU 2 interface and abide by the contract that a VAFU2_CNTXT structure will
      // appear at byte offset 0 within the supplied AFU Context workspace.

      // Initialize the command buffer
      ::memset(pVAFU2_cntxt, 0, sizeof(VAFU2_CNTXT));
      pVAFU2_cntxt->num_cl  = a_num_cl;
      pVAFU2_cntxt->pSource = pSource;
      pVAFU2_cntxt->pDest   = pDest;

      MSG("VAFU2 Context=" << std::hex << (void *)pVAFU2_cntxt <<
          " Src="          << std::hex << (void *)pVAFU2_cntxt->pSource <<
          " Dest="         << std::hex << (void *)pVAFU2_cntxt->pDest << std::dec);
      MSG("Cache lines in each buffer="  << std::dec << pVAFU2_cntxt->num_cl <<
          " (bytes="       << std::dec << pVAFU2_cntxt->num_cl * CL(1) <<
          " 0x"            << std::hex << pVAFU2_cntxt->num_cl * CL(1) << std::dec << ")");

      // Init the src/dest buffers, based on the desired sequence (either fixed or random).
      MSG("Initializing source buffer with random pattern. (src=random 32 bits unsigned integer)");

      //std::srand((uint)std::time(0));





      for (int i = 0; i < a_num_bytes; i++) {
          //char random = (char) (std::rand() % 256);
          char random = (char) (random_function() % 256);
          ::memset( pSource + i, random, 1);
      }
     

      MSG("Initializing destination buffer with fixed pattern. (dest=0xbebebebe)");
      
      //::memset( pSource, 0xAF, a_num_bytes - 3);
      ::memset( pDest,   0xBE, a_num_bytes );

      // Buffers have been initialized
      ////////////////////////////////////////////////////////////////////////////

      ////////////////////////////////////////////////////////////////////////////
      // Get the AFU and start talking to it

      // Acquire the AFU. Once acquired in a TransactionContext, can issue CSR Writes and access DSM.
      // Provide a workspace and so also start the task.
      // The VAFU2 Context is assumed to be at the start of the workspace.
      MSG("Starting SPL Transaction with Workspace");
      m_SPLService->StartTransactionContext(TransactionID(), pWSUsrVirt, 100);
      m_Sem.Wait();

      // The AFU is running
      ////////////////////////////////////////////////////////////////////////////

      ////////////////////////////////////////////////////////////////////////////
      // Wait for the AFU to be done. This is AFU-specific, we have chosen to poll ...

      // Set timeout increment based on hardware, software, or simulation
      bt32bitInt count(timeout * 1000 / sleep_interval);  // 10 seconds with 10 millisecond sleep
      bt32bitInt delay(sleep_interval);   // 10 milliseconds is the default

      // Wait for SPL VAFU to finish code
      volatile bt32bitInt done = pVAFU2_cntxt->Status & VAFU2_CNTXT_STATUS_DONE;
      btUnsigned32bitInt curr_line = 1;

      btUnsigned32bitInt   tCacheLine[16];   // Temporary cacheline for various purposes
      CASSERT( sizeof(tCacheLine) == CL(1) );

      // in order to know whether the destination cacheline has been sorted to not.
      ::memset(tCacheLine, 0xBE, CL(1));
      MSG("Block Size = " << block_size << ", Input Size = " << num_MB << "MB");

      btUnsigned32bitInt *pDestInt = reinterpret_cast<btUnsigned32bitInt *>(pDest);
      MSG("AFU sorting cacheline and CPU merging at the same time...");
      int p, k;
      // record the start time in ms


      timespec start_time;
	  timespec search_latency;
      timespec curr_time;
      timespec diff;
      timespec merge_start;
	  timespec merge_end;
      
      bool hw_sorted = false;
      bool hw_started = false;
      bool time_recorded = false;
     // check whether curr_line has been sorted
     btUnsigned32bitInt curr_block = 1;
     btUnsigned32bitInt a_num_block = a_num_cl / block_size;
	 btUnsigned32bitInt num_tasks = num_threads;
	 
	  MSG("Value of a_num_cl");
	  MSG(a_num_cl);
	  MSG("Value of a_num_bytes");
	  MSG(a_num_bytes);
	  MSG("Value of a_num_block");
	  MSG(a_num_block);
	 
	
	  
     while (curr_block <= a_num_block) {	
   
        if (::memcmp(tCacheLine, &pDestCL[0], CL(1)) != 0 && hw_started == false) {
	    //if (::memcmp(0xbe, (&pDestCL[0]), sizeof(btUnsigned32bitInt)) != 0 
		         //&& hw_started == false) 
            clock_gettime(CLOCK_REALTIME, &start_time);
            hw_started = true;
         }

        //if (::memcmp(tCacheLine, &pDestCL[1], CL(1)) != 0 && time_recorded == false) {
        //    clock_gettime(CLOCK_REALTIME, &search_latency);
		//	diff = calculate_time_interval(search_latency, start_time);
		//	double elaps = (double)diff.tv_sec*1000000000 + (double)diff.tv_nsec;
        //    MSG("***Hardware search latency is " << elaps << "ns");
		//	time_recorded = true;
        // }
		 
		 /*
         if (::memcmp(tCacheLine, &pDestCL[a_num_cl-1], CL(1)) != 0 && hw_sorted == false) {
              //clock_gettime(CLOCK_REALTIME, &curr_time);
              //diff = calculate_time_interval(curr_time, start_time);
              //
              //double elaps = (double)diff.tv_sec*1000000000 + (double)diff.tv_nsec;
              //MSG("***Hardware total search process takes " << elaps << "ns");
              //MSG("Estimated throughput: " << (double)num_MB*1000/1024*1000/(elaps/1000) << "GB/s");
              hw_sorted = true;
         }*/


         if (::memcmp(tCacheLine, &pDestCL[(curr_block) *  block_size - 1], CL(1)) != 0
 		       && hw_started == true ) 
		//if (::memcmp(0xbe, (&pDestCL[(curr_block) *  block_size - 1]), sizeof(btUnsigned32bitInt)) != 0 && hw_started == true) 
		 {

			 btUnsigned32bitInt *pDestNext = pDestInt + (curr_block - 1) * 16 * block_size;		 
			 
			 
			for(int jj = 0; jj < block_size/num_tasks; jj++) {  
			   
                btUnsigned32bitInt *pDestNextMulti = pDestNext + jj*num_tasks*16;
				
			    bt16bitInt ** idxOutGroup = new bt16bitInt *[num_tasks];
				//bt16bitInt *idxOutGroup = reinterpret_cast<bt16bitInt *> pDestNextMulti;
				//btUnsigned32bitInt *pDestInt = reinterpret_cast<btUnsigned32bitInt *>(pDest);
		        bt16bitInt *result = new bt16bitInt [num_tasks];
			     
			    for(int i = 0; i < num_tasks; i++) {
                    idxOutGroup[i] = new bt16bitInt[num_set];
			        result[i] = 0;
                }
			 
                //merge_hardware(pDestInt + (curr_block - 1) * 16 * block_size, 16 * block_size);
			    for(int i = 0; i < num_tasks; i++){
	               for(int k = 0; k < num_set; k++)
	              {
		        //bt16bitInt setIdx = setGroupIdx[i] % (1<<tree_depth);		   
		            //idxOutGroup[i][k] = ((bt16bitInt)(*(pDestNextMulti 
		            //                     // + (curr_block - 1) * 32 * block_size    //one block 16 cache lines
		 			//					 + i*16          // one cl 16 32-bit data
		 			//					 //+ j*num_set   // one cl two set groups
					//		             + k
		 			//					   )));
					
					//TEST1
					idxOutGroup[i][k] = 5;
		       // std::cout<<setData[i][k]<<",";
	              }
	            // std::cout<<std::endl;
	           }
	         
			    //if(jj == 1 && curr_block == 1)
		        //    clock_gettime(CLOCK_REALTIME, &merge_start);			
			
               //call parallel
			   setIntersec16par(num_setgroup,num_set,setData,idxOutGroup,result,num_tasks);
			   
			   //if(jj == 1 && curr_block == 1){
		       //    clock_gettime(CLOCK_REALTIME, &merge_end);		
			   //    diff = calculate_time_interval(merge_end, merge_start);
			   //    double elaps = (double)diff.tv_sec*1000000000 + (double)diff.tv_nsec;
               //    MSG("***CPU merge latency is " << elaps << "ns");
			   //}
			    
			    for(int i = 0; i < num_tasks; ++i) {
                  delete [] idxOutGroup[i];
               }
               
	           delete [] idxOutGroup;
               delete [] result;
			   
			}
			
			
			curr_block += 1;
         }
		 
     }

	
      clock_gettime(CLOCK_REALTIME, &curr_time);

      diff = calculate_time_interval(curr_time, start_time);
      MSG("The whole look up and merge process takes " << (double)diff.tv_sec*1000 + (double)diff.tv_nsec/1000000 << "ms");
	  

      done = pVAFU2_cntxt->Status & VAFU2_CNTXT_STATUS_DONE;
      
      while (!done && count > 0) {
          SleepMilli(delay);
          done = pVAFU2_cntxt->Status & VAFU2_CNTXT_STATUS_DONE;
          count -= 1;
      }


      if ( !done ) {
         // must have dropped out of loop due to count -- never saw update
         ERR("AFU never signaled it was done. Timing out anyway. Results may be strange.\n");
      } else if (curr_block != a_num_block + 1) {
         ERR("The number of last line to merge is wrong.\n");
      } else {
         // merge the last line
		 ERR("Merged all the cache lines.\n");
         //merge_hardware(pDestInt + (curr_block - 1) * 16 * block_size, 16 * block_size);
         // p = 4;

         // k = curr_block;
         // while ((curr_block + 1) % p == 0) {
            // k = k - p / 2;

            // merge(pDestInt + (k - 1) * 16 * block_size, p * 8 * block_size);
            // p *= 2;
         // }
      }

      ////////////////////////////////////////////////////////////////////////////
     // Stop the AFU

     // Issue Stop Transaction and wait for OnTransactionStopped
     MSG("Stopping SPL Transaction");
     m_SPLService->StopTransactionContext(TransactionID());
     m_Sem.Wait();
     MSG("SPL Transaction complete");

     ////////////////////////////////////////////////////////////////////////////
     // Check the buffers to make sure they copied okay

     btUnsignedInt        cl;               // Loop counter. Cache-Line number.
     int                  tres;              // If many errors in buffer, only dump a limited number
     btInt                res = 0;
     ostringstream        oss("");          // Place to stash fancy strings


   
     MSG("Start look up and merge in  in Source Memory using standard library quick sort...");
     btUnsigned32bitInt *pSourceInt = reinterpret_cast<btUnsigned32bitInt *>(pSource);










     bt16bitInt *pKeyInt = reinterpret_cast<bt16bitInt *>(pSource);
	 bt16bitInt *pIdxInt = reinterpret_cast<bt16bitInt *>(pSource);
	 std::vector<bt16bitInt> intsecGroup;	 
     // use std::qsort
     clock_gettime(CLOCK_REALTIME, &start_time);
     //qsort(pSourceInt, a_num_cl * 16, sizeof(btUnsigned32bitInt), compareUint);




	 for(int i=0; i<a_num_cl; i++)
	 {
		 //std::vector<bt16bitInt> setGroupIdx;
		 std::vector<bt16bitInt> idxOut;
		 bt16bitInt intsec;
		 //bt16bitInt random = (bt16bitInt)random_function();
		 //idxOut.push_back(random);
		 //MSG("STEP2");
		 
		 for(int j=0; j<num_set; j++)
		  {
		      bt16bitInt * keyIn;
		      bt16bitInt * idxIn;   //byte size
			// MSG("STEP3");			   
		      keyIn = pKeyInt + 31 - j;
			// MSG(pKeyInt); MSG(keyIn);
			  //MSG("STEP4");
		     idxIn = pIdxInt + 15; 
			 bool idxInBool = ((*idxIn) >> (15-j)) & 0x1;
			 
			 // MSG(pIdxInt); MSG(idxIn);
			 // MSG("STEP5");
			 bt16bitInt idxOutTmp ;
		      //idxOutTmp = lookup(*keyIn, idxInBool);
			  idxOutTmp = 0;
			  //MSG("STEP6");
		      idxOut.push_back(idxOutTmp);
		 }
		 
		 //MSG("STEP7");
		 pKeyInt += 32;
		 pIdxInt += 32;
		 
		 //setGroupIdx = ((unsigned int)idxOut[0]) % num_setgroup;
		 //intsec = merge_software(idxOut);
		 intsecGroup.push_back(intsec);
	 }
     clock_gettime(CLOCK_REALTIME, &curr_time);
     diff = calculate_time_interval(curr_time, start_time);
     MSG("CPU lookup and merge takes " << (double)diff.tv_sec*1000 + (double)diff.tv_nsec/1000000 << "ms");






     MSG("Finish look up and merge in Source Memory");
     MSG("Final checking...");
     bool success = true;
     for(cl = 0; cl < a_num_cl; cl++) {
         ::memcpy( tCacheLine, &pSourceCL[cl], CL(1));
         if (::memcmp(tCacheLine, &pDestCL[cl], CL(1))) {
           Show2CLs( tCacheLine, &pDestCL[cl], oss);
           ERR("Destination cache line " << cl << " @" << (void*)&pDestCL[cl] <<
                 " is not what was expected.\n" << oss.str() );
           oss.str(std::string(""));
           success = false;
           break;
         }
     }
     if (success) {
         MSG("All tests passed! Congratulations!");
     }
   }

   ////////////////////////////////////////////////////////////////////////////
   // Clean up and exit
   MSG("Workspace verification complete, freeing workspace.");
   m_SPLService->WorkspaceFree(m_pWkspcVirt, TransactionID());
   m_Sem.Wait();

   m_runtimClient->end();
   return m_Result;
}

// We must implement the IServiceClient interface (IServiceClient.h):

// <begin IServiceClient interface>
void HelloSPLLBApp::serviceAllocated(IBase *pServiceBase,
                                     TransactionID const &rTranID)
{
   m_pAALService = pServiceBase;
   ASSERT(NULL != m_pAALService);

   // Documentation says SPLAFU Service publishes ISPLAFU as subclass interface
   m_SPLService = subclass_ptr<ISPLAFU>(pServiceBase);

   ASSERT(NULL != m_SPLService);
   if ( NULL == m_SPLService ) {
      return;
   }

   MSG("Service Allocated");

   // Allocate Workspaces needed. ASE runs more slowly and we want to watch the transfers,
   //   so have fewer of them.
   #if defined ( ASEAFU )
   #define LB_BUFFER_SIZE CL(16*num_KB)
   #else
   #define LB_BUFFER_SIZE MB(num_MB)
   #endif

   m_SPLService->WorkspaceAllocate(sizeof(VAFU2_CNTXT) + LB_BUFFER_SIZE + LB_BUFFER_SIZE,
      TransactionID());

}

void HelloSPLLBApp::serviceAllocateFailed(const IEvent &rEvent)
{
   IExceptionTransactionEvent * pExEvent = dynamic_ptr<IExceptionTransactionEvent>(iidExTranEvent, rEvent);
   ERR("Failed to allocate a Service");
   ERR(pExEvent->Description());
   ++m_Result;
   m_Sem.Post(1);
}

void HelloSPLLBApp::serviceFreed(TransactionID const &rTranID)
{
   MSG("Service Freed");
   // Unblock Main()
   m_Sem.Post(1);
}

 // <ISPLClient>
void HelloSPLLBApp::OnWorkspaceAllocated(TransactionID const &TranID,
                                          btVirtAddr           WkspcVirt,
                                          btPhysAddr           WkspcPhys,
                                          btWSSize             WkspcSize)
{
   AutoLock(this);

   m_pWkspcVirt = WkspcVirt;
   m_WkspcSize = WkspcSize;

   MSG("Got Workspace");         // Got workspace so unblock the Run() thread
   m_Sem.Post(1);
}

void HelloSPLLBApp::OnWorkspaceAllocateFailed(const IEvent &rEvent)
{
   IExceptionTransactionEvent * pExEvent = dynamic_ptr<IExceptionTransactionEvent>(iidExTranEvent, rEvent);
   ERR("OnWorkspaceAllocateFailed");
   ERR(pExEvent->Description());
   ++m_Result;
   m_Sem.Post(1);
}

void HelloSPLLBApp::OnWorkspaceFreed(TransactionID const &TranID)
{
   MSG("OnWorkspaceFreed");
   // Freed so now Release() the Service through the Services IAALService::Release() method
   (dynamic_ptr<IAALService>(iidService, m_pAALService))->Release(TransactionID());
}

void HelloSPLLBApp::OnWorkspaceFreeFailed(const IEvent &rEvent)
{
   IExceptionTransactionEvent * pExEvent = dynamic_ptr<IExceptionTransactionEvent>(iidExTranEvent, rEvent);
   ERR("OnWorkspaceAllocateFailed");
   ERR(pExEvent->Description());
   ++m_Result;
   m_Sem.Post(1);
}

/// CMyApp Client implementation of ISPLClient::OnTransactionStarted
void HelloSPLLBApp::OnTransactionStarted( TransactionID const &TranID,
                                   btVirtAddr           AFUDSMVirt,
                                   btWSSize             AFUDSMSize)
{
   MSG("Transaction Started");
   m_AFUDSMVirt = AFUDSMVirt;
   m_AFUDSMSize =  AFUDSMSize;
   m_Sem.Post(1);
}
/// CMyApp Client implementation of ISPLClient::OnContextWorkspaceSet
void HelloSPLLBApp::OnContextWorkspaceSet( TransactionID const &TranID)
{
   MSG("Context Set");
   m_Sem.Post(1);
}
/// CMyApp Client implementation of ISPLClient::OnTransactionFailed
void HelloSPLLBApp::OnTransactionFailed( const IEvent &rEvent)
{
   IExceptionTransactionEvent * pExEvent = dynamic_ptr<IExceptionTransactionEvent>(iidExTranEvent, rEvent);
   ERR("Runtime AllocateService failed");
   ERR(pExEvent->Description());
   m_bIsOK = false;
   ++m_Result;
   m_AFUDSMVirt = NULL;
   m_AFUDSMSize =  0;
   ERR("Transaction Failed");
   m_Sem.Post(1);
}
/// CMyApp Client implementation of ISPLClient::OnTransactionComplete
void HelloSPLLBApp::OnTransactionComplete( TransactionID const &TranID)
{
   m_AFUDSMVirt = NULL;
   m_AFUDSMSize =  0;
   MSG("Transaction Complete");
   m_Sem.Post(1);
}
/// CMyApp Client implementation of ISPLClient::OnTransactionStopped
void HelloSPLLBApp::OnTransactionStopped( TransactionID const &TranID)
{
   m_AFUDSMVirt = NULL;
   m_AFUDSMSize =  0;
   MSG("Transaction Stopped");
   m_Sem.Post(1);
}
void HelloSPLLBApp::serviceEvent(const IEvent &rEvent)
{
   ERR("unexpected event 0x" << hex << rEvent.SubClassID());
}
// <end IServiceClient interface>

void HelloSPLLBApp::Show2CLs(void          *pCLExpected, // pointer to cache-line expected
                             void          *pCLFound,    // pointer to found cache line
                             ostringstream &oss)         // add it to this ostringstream
{
   oss << "Expected: ";
   _DumpCL(pCLExpected, oss);
   oss << "\n";
   oss << "Found:    ";
   _DumpCL(pCLFound, oss);
}  // _DumpCL

 void HelloSPLLBApp::_DumpCL( void         *pCL,  // pointer to cache-line to print
                              ostringstream &oss)  // add it to this ostringstream
 {
    oss << std::hex << std::setfill('0') << std::uppercase;
    btUnsigned32bitInt *pu32 = reinterpret_cast<btUnsigned32bitInt*>(pCL);
    for( int i = 0; i < ( CL(1) / sizeof(btUnsigned32bitInt)); ++i ) {
       oss << "0x" << std::setw(8) << *pu32 << " ";
       ++pu32;
    }
    oss << std::nouppercase;
 }  // _DumpCL

/// @} group HelloSPLLB


//=============================================================================
// Name: main
// Description: Entry point to the application
// Inputs: none
// Outputs: none
// Comments: Main initializes the system. The rest of the example is implemented
//           in the objects.
//=============================================================================
int main(int argc, char *argv[])
{
   RuntimeClient  runtimeClient;
   HelloSPLLBApp theApp(&runtimeClient);

   if(!runtimeClient.isOK()){
      ERR("Runtime Failed to Start");
      exit(1);
   }
   btInt Result = theApp.run();

   MSG("Done");
   return Result;
}


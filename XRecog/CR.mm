//
//  CR.cpp
//  prrr
//
//  Created by Daniele Ciriello on 13/11/14.
//  Copyright (c) 2014 Daniele Ciriello. All rights reserved.
//

#include "CR.h"

#include "ViewController.h"

ViewController *parent = nil;



CorrespondenceGrouping::CorrespondenceGrouping(){
    setupDefaultValues();
}
CorrespondenceGrouping::CorrespondenceGrouping(std::string model_filename_,
                                               std::string scene_filename_ ){
    

    setupDefaultValues();
    model_filename = model_filename_;
    scene_filename = scene_filename_;

    
}
CorrespondenceGrouping::CorrespondenceGrouping(std::string model_filename_,
                                               std::string scene_filename_,
                                               bool show_keypoints_,
                                               bool show_correspondences_,
                                               bool use_cloud_resolution_,
                                               bool use_hough_ ){
    
    setupDefaultValues();
    model_filename              = model_filename_;
    scene_filename              = scene_filename_;
    show_keypoints              = show_keypoints_;
    show_correspondences        = show_correspondences_;
    use_cloud_resolution        = use_cloud_resolution_;
    use_hough                   = use_hough_;

    
}

CorrespondenceGrouping::CorrespondenceGrouping(std::string model_filename_,
                                               std::string scene_filename_,
                                               bool show_keypoints_,
                                               bool show_correspondences_,
                                               bool use_cloud_resolution_,
                                               bool use_hough_,
                                               bool transform_model_,
                                               float model_ss_ ,
                                               float scene_ss_,
                                               float rf_rad_ ,
                                               float descr_rad_,
                                               float cg_size_,
                                               float cg_thresh_ ){
    
        setupDefaultValues();
        model_filename          = model_filename_;
        scene_filename          = scene_filename_;
        show_keypoints          = show_keypoints_;
        show_correspondences    = show_correspondences_;
        use_cloud_resolution    = use_cloud_resolution_;
        use_hough               = use_hough_;
        transform_model         = transform_model_;
        model_ss                = model_ss_;
        scene_ss                = scene_ss_;
        rf_rad                  = rf_rad_;
        descr_rad               = descr_rad_;
        cg_size                 = cg_size_;
        cg_thresh               = cg_thresh_;
    
    }



void CorrespondenceGrouping::setupDefaultValues(){
    model_filename = "/Users/mbp/Documents/projects/QRecog/pointclouds.org/correspondence_grouping/build/Debug/milk.pcd";
    scene_filename = "/Users/mbp/Documents/projects/QRecog/pointclouds.org/correspondence_grouping/build/Debug/milk_cartoon_all_small_clorox.pcd";
    //Algorithm params
    show_keypoints = false;
    show_correspondences = false;
    use_cloud_resolution = false;
    use_hough = true ;
    transform_model = false;
    model_ss = 0.01f;
    scene_ss = 0.03f;
    rf_rad = 0.015f;
    descr_rad = 0.02f;
    cg_size = 0.01f;
    cg_thresh = 5.0f;
    stopValue = false;
}

double CorrespondenceGrouping::computeCloudResolution (const pcl::PointCloud<PointType>::ConstPtr &cloud)
    {
        double res = 0.0;
        int n_points = 0;
        int nres;
        std::vector<int> indices (2);
        std::vector<float> sqr_distances (2);
        pcl::search::KdTree<PointType> tree;
        tree.setInputCloud (cloud);
        
        for (size_t i = 0; i < cloud->size (); ++i)
        {
            if (! pcl_isfinite ((*cloud)[i].x))
            {
                continue;
            }
            //Considering the second neighbor since the first is the point itself.
            nres = tree.nearestKSearch (i, 2, indices, sqr_distances);
            if (nres == 2)
            {
                res += sqrt (sqr_distances[1]);
                ++n_points;
            }
        }
        if (n_points != 0)
        {
            res /= n_points;
        }
        return res;
    }

void CorrespondenceGrouping::stop(){
    stopValue = true;
}
    
void CorrespondenceGrouping::run ()
    {
        
        pcl::PointCloud<PointType>::Ptr model (new pcl::PointCloud<PointType> ());
        pcl::PointCloud<PointType>::Ptr model_keypoints (new pcl::PointCloud<PointType> ());
        pcl::PointCloud<PointType>::Ptr scene (new pcl::PointCloud<PointType> ());
        pcl::PointCloud<PointType>::Ptr scene_keypoints (new pcl::PointCloud<PointType> ());
        pcl::PointCloud<NormalType>::Ptr model_normals (new pcl::PointCloud<NormalType> ());
        pcl::PointCloud<NormalType>::Ptr scene_normals (new pcl::PointCloud<NormalType> ());
        pcl::PointCloud<DescriptorType>::Ptr model_descriptors (new pcl::PointCloud<DescriptorType> ());
        pcl::PointCloud<DescriptorType>::Ptr scene_descriptors (new pcl::PointCloud<DescriptorType> ());
        
        //
        //  Load clouds
        //
        if (pcl::io::loadPCDFile (model_filename, *model) < 0)
        {
            std::cout << "Error loading model cloud." << std::endl;
            return;
        }
        if (pcl::io::loadPCDFile (scene_filename, *scene) < 0)
        {
            std::cout << "Error loading scene cloud." << std::endl;
            return;
        }
        
        if (transform_model == true) {
            //NSLog(@"czvsdvc");
            //transformCloud(model);
        }
        
        //
        //  Set up resolution invariance
        //
        if (use_cloud_resolution)
        {
            float resolution = static_cast<float> (computeCloudResolution (model));
            if (resolution != 0.0f)
            {
                model_ss   *= resolution;
                scene_ss   *= resolution;
                rf_rad     *= resolution;
                descr_rad  *= resolution;
                cg_size    *= resolution;
            }
            
            std::cout << "Model resolution:       " << resolution << std::endl;
            std::cout << "Model sampling size:    " << model_ss << std::endl;
            std::cout << "Scene sampling size:    " << scene_ss << std::endl;
            std::cout << "LRF support radius:     " << rf_rad << std::endl;
            std::cout << "SHOT descriptor radius: " << descr_rad << std::endl;
            std::cout << "Clustering bin size:    " << cg_size << std::endl << std::endl;
        }
        
        //
        //  Compute Normals
        //
        pcl::NormalEstimationOMP<PointType, NormalType> norm_est;
        norm_est.setKSearch (10);
        norm_est.setInputCloud (model);
        norm_est.compute (*model_normals);
        
        norm_est.setInputCloud (scene);
        norm_est.compute (*scene_normals);
        
        //
        //  Downsample Clouds to Extract keypoints
        //
        pcl::PointCloud<int> sampled_indices;
        
        pcl::UniformSampling<PointType> uniform_sampling;
        uniform_sampling.setInputCloud (model);
        uniform_sampling.setRadiusSearch (model_ss);
        uniform_sampling.compute (sampled_indices);
        pcl::copyPointCloud (*model, sampled_indices.points, *model_keypoints);
        
        [parent setTotalModelPoints:model->size()];
        [parent setModelKeypoints:model_keypoints->size()];
        
        uniform_sampling.setInputCloud (scene);
        uniform_sampling.setRadiusSearch (scene_ss);
        uniform_sampling.compute (sampled_indices);
        pcl::copyPointCloud (*scene, sampled_indices.points, *scene_keypoints);
        
        [parent setTotalScenePoints:scene->size()];
        [parent setSceneKeypoints:scene_keypoints->size()];

        
        //
        //  Compute Descriptor for keypoints
        //
        pcl::SHOTEstimationOMP<PointType, NormalType, DescriptorType> descr_est;
        descr_est.setRadiusSearch (descr_rad);
        
        descr_est.setInputCloud (model_keypoints);
        descr_est.setInputNormals (model_normals);
        descr_est.setSearchSurface (model);
        descr_est.compute (*model_descriptors);
        
        descr_est.setInputCloud (scene_keypoints);
        descr_est.setInputNormals (scene_normals);
        descr_est.setSearchSurface (scene);
        descr_est.compute (*scene_descriptors);
        
        //
        //  Find Model-Scene Correspondences with KdTree
        //
        pcl::CorrespondencesPtr model_scene_corrs (new pcl::Correspondences ());
        
        pcl::KdTreeFLANN<DescriptorType> match_search;
        match_search.setInputCloud (model_descriptors);
        
        //  For each scene keypoint descriptor, find nearest neighbor into the model keypoints descriptor cloud and add it to the correspondences vector.
        for (size_t i = 0; i < scene_descriptors->size (); ++i)
        {
            std::vector<int> neigh_indices (1);
            std::vector<float> neigh_sqr_dists (1);
            if (!pcl_isfinite (scene_descriptors->at (i).descriptor[0])) //skipping NaNs
            {
                continue;
            }
            int found_neighs = match_search.nearestKSearch (scene_descriptors->at (i), 1, neigh_indices, neigh_sqr_dists);
            if(found_neighs == 1 && neigh_sqr_dists[0] < 0.25f) //  add match only if the squared descriptor distance is less than 0.25 (SHOT descriptor distances are between 0 and 1 by design)
            {
                pcl::Correspondence corr (neigh_indices[0], static_cast<int> (i), neigh_sqr_dists[0]);
                model_scene_corrs->push_back (corr);
            }
        }
        std::cout << "Correspondences found: " << model_scene_corrs->size () << std::endl;
        
        //
        //  Actual Clustering
        //
        std::vector<Eigen::Matrix4f, Eigen::aligned_allocator<Eigen::Matrix4f> > rototranslations;
        std::vector<pcl::Correspondences> clustered_corrs;
        
        //  Using Hough3D
        if (use_hough)
        {
            //
            //  Compute (Keypoints) Reference Frames only for Hough
            //
            pcl::PointCloud<RFType>::Ptr model_rf (new pcl::PointCloud<RFType> ());
            pcl::PointCloud<RFType>::Ptr scene_rf (new pcl::PointCloud<RFType> ());
            
            pcl::BOARDLocalReferenceFrameEstimation<PointType, NormalType, RFType> rf_est;
            rf_est.setFindHoles (true);
            rf_est.setRadiusSearch (rf_rad);
            
            rf_est.setInputCloud (model_keypoints);
            rf_est.setInputNormals (model_normals);
            rf_est.setSearchSurface (model);
            rf_est.compute (*model_rf);
            
            rf_est.setInputCloud (scene_keypoints);
            rf_est.setInputNormals (scene_normals);
            rf_est.setSearchSurface (scene);
            rf_est.compute (*scene_rf);
            
            //  Clustering
            pcl::Hough3DGrouping<PointType, PointType, RFType, RFType> clusterer;
            clusterer.setHoughBinSize (cg_size);
            clusterer.setHoughThreshold (cg_thresh);
            clusterer.setUseInterpolation (true);
            clusterer.setUseDistanceWeight (false);
            
            clusterer.setInputCloud (model_keypoints);
            clusterer.setInputRf (model_rf);
            clusterer.setSceneCloud (scene_keypoints);
            clusterer.setSceneRf (scene_rf);
            clusterer.setModelSceneCorrespondences (model_scene_corrs);
            
            //clusterer.cluster (clustered_corrs);
            clusterer.recognize (rototranslations, clustered_corrs);
            model_rf = nullptr;
            scene_rf = nullptr;
        }
        else // Using GeometricConsistency
        {
            pcl::GeometricConsistencyGrouping<PointType, PointType> gc_clusterer;
            gc_clusterer.setGCSize (cg_size);
            gc_clusterer.setGCThreshold (cg_thresh);
            
            gc_clusterer.setInputCloud (model_keypoints);
            gc_clusterer.setSceneCloud (scene_keypoints);
            gc_clusterer.setModelSceneCorrespondences (model_scene_corrs);
            
            //gc_clusterer.cluster (clustered_corrs);
            gc_clusterer.recognize (rototranslations, clustered_corrs);
        }
        
        //
        //  Output results
        //
        std::cout << "Model instances found: " << rototranslations.size () << std::endl;
        for (size_t i = 0; i < rototranslations.size (); ++i)
        {
            std::cout << "\n    Instance " << i + 1 << ":" << std::endl;
            std::cout << "        Correspondences belonging to this instance: " << clustered_corrs[i].size () << std::endl;
            
            // Print the rotation matrix and translation vector
            Eigen::Matrix3f rotation = rototranslations[i].block<3,3>(0, 0);
            Eigen::Vector3f translation = rototranslations[i].block<3,1>(0, 3);
            
            printf ("\n");
            printf ("            | %6.3f %6.3f %6.3f | \n", rotation (0,0), rotation (0,1), rotation (0,2));
            printf ("        R = | %6.3f %6.3f %6.3f | \n", rotation (1,0), rotation (1,1), rotation (1,2));
            printf ("            | %6.3f %6.3f %6.3f | \n", rotation (2,0), rotation (2,1), rotation (2,2));
            printf ("\n");
            printf ("        t = < %0.3f, %0.3f, %0.3f >\n", translation (0), translation (1), translation (2));
        }
        
        //
        //  Visualization
        //
        pcl::visualization::PCLVisualizer viewer = pcl::visualization::PCLVisualizer::PCLVisualizer("Correspondence Grouping");
        viewer.addPointCloud (scene, "scene_cloud");
        
        pcl::PointCloud<PointType>::Ptr off_scene_model (new pcl::PointCloud<PointType> ());
        pcl::PointCloud<PointType>::Ptr off_scene_model_keypoints (new pcl::PointCloud<PointType> ());
        
        if (show_correspondences || show_keypoints)
        {
            //  We are translating the model so that it doesn't end in the middle of the scene representation
            pcl::transformPointCloud (*model, *off_scene_model, Eigen::Vector3f (-1,0,0), Eigen::Quaternionf (1, 0, 0, 0));
            pcl::transformPointCloud (*model_keypoints, *off_scene_model_keypoints, Eigen::Vector3f (-1,0,0), Eigen::Quaternionf (1, 0, 0, 0));
            
            pcl::visualization::PointCloudColorHandlerCustom<PointType> off_scene_model_color_handler (off_scene_model, 255, 255, 128);
            viewer.addPointCloud (off_scene_model, off_scene_model_color_handler, "off_scene_model");
        }
        
        if (show_keypoints)
        {
            pcl::visualization::PointCloudColorHandlerCustom<PointType> scene_keypoints_color_handler (scene_keypoints, 0, 0, 255);
            viewer.addPointCloud (scene_keypoints, scene_keypoints_color_handler, "scene_keypoints");
            viewer.setPointCloudRenderingProperties (pcl::visualization::PCL_VISUALIZER_POINT_SIZE, 5, "scene_keypoints");
            
            pcl::visualization::PointCloudColorHandlerCustom<PointType> off_scene_model_keypoints_color_handler (off_scene_model_keypoints, 0, 0, 255);
            viewer.addPointCloud (off_scene_model_keypoints, off_scene_model_keypoints_color_handler, "off_scene_model_keypoints");
            viewer.setPointCloudRenderingProperties (pcl::visualization::PCL_VISUALIZER_POINT_SIZE, 5, "off_scene_model_keypoints");
        }
        
        for (size_t i = 0; i < rototranslations.size (); ++i)
        {
            pcl::PointCloud<PointType>::Ptr rotated_model (new pcl::PointCloud<PointType> ());
            pcl::transformPointCloud (*model, *rotated_model, rototranslations[i]);
            
            std::stringstream ss_cloud;
            ss_cloud << "instance" << i;
            
            pcl::visualization::PointCloudColorHandlerCustom<PointType> rotated_model_color_handler (rotated_model, 255, 0, 0);
            viewer.addPointCloud (rotated_model, rotated_model_color_handler, ss_cloud.str ());
            
            if (show_correspondences)
            {
                for (size_t j = 0; j < clustered_corrs[i].size (); ++j)
                {
                    std::stringstream ss_line;
                    ss_line << "correspondence_line" << i << "_" << j;
                    PointType& model_point = off_scene_model_keypoints->at (clustered_corrs[i][j].index_query);
                    PointType& scene_point = scene_keypoints->at (clustered_corrs[i][j].index_match);
                    
                    //  We are drawing a line for each pair of clustered correspondences found between the model and the scene
                    viewer.addLine<PointType, PointType> (model_point, scene_point, 0, 255, 0, ss_line.str ());
                }
            }
        }
        while ( !viewer.wasStopped ())
        {
            viewer.spinOnce ();
        }
        //viewer.~PCLVisualizer();        //rotated_model = nullptr;

}

void CorrespondenceGrouping::transformCloud(pcl::PointCloud<PointType>::Ptr &cloud){
    /*  METHOD #2: Using a Affine3f
     This method is easier and less error prone
     */
    Eigen::Affine3f transform = Eigen::Affine3f::Identity();
    float theta = M_PI/4; // The angle of rotation in radians

    // Define a translation of 2.5 meters on the x axis.
    transform.translation() << 0.0, 0.0, 0.0;
    
    // The same rotation matrix as before; tetha radians arround Z axis
    transform.rotate (Eigen::AngleAxisf (theta, Eigen::Vector3f::UnitZ()));
    
    // Print the transformation
    printf ("\nApplying Transform using an Affine3f\n");
    std::cout << transform.matrix() << std::endl;
    
    pcl::transformPointCloud (*cloud, *cloud, transform);

}


void CorrespondenceGrouping::setParent(id _parent){
    parent = _parent;
}

//int CorrespondenceGrouping::_run (void *objectiveCObject, void *aParameter)
//{
//    // To invoke an Objective-C method from C++, use
//    // the C trampoline function
//    return MyObjectDoSomethingWith (objectiveCObject, aParameter);
//}






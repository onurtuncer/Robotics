#include <pinocchio/multibody/model.hpp>
#include <pinocchio/multibody/data.hpp>
#include <pinocchio/algorithm/kinematics.hpp>

#include <pinocchio/spatial/se3.hpp>
#include <pinocchio/spatial/inertia.hpp>

#include <Eigen/Core>
#include <Eigen/Geometry>

#include <iostream>
#include <cmath>

int main()
{
    using namespace pinocchio;

    Model model;

    // joint1 at origin (RZ)
    Model::JointIndex j1 = model.addJoint(
        model.getJointId("universe"),
        JointModelRZ(),
        SE3::Identity(),
        "j1");

    // Link1 inertia: mass=1 kg, COM=(0.5,0,0), small rotational inertia
    Eigen::Matrix3d J1 = Eigen::Matrix3d::Identity() * 1e-2;
    Inertia I1(1.0, Eigen::Vector3d(0.5, 0.0, 0.0), J1);
    model.appendBodyToJoint(j1, I1, SE3::Identity());

    // joint2 placed 1 m along x from joint1
    SE3 j2_placement = SE3::Identity();
    j2_placement.translation() = Eigen::Vector3d(1.0, 0.0, 0.0);

    Model::JointIndex j2 = model.addJoint(
        j1,
        JointModelRZ(),
        j2_placement,
        "j2");

    // Link2 inertia
    Eigen::Matrix3d J2 = Eigen::Matrix3d::Identity() * 1e-2;
    Inertia I2(1.0, Eigen::Vector3d(0.5, 0.0, 0.0), J2);
    model.appendBodyToJoint(j2, I2, SE3::Identity());

    Data data(model);

    // q has size model.nq  (note: nq is a field on this branch)
    Eigen::VectorXd q = Eigen::VectorXd::Zero(model.nq);
    q[0] = M_PI / 6.0;  // 30°
    q[1] = -M_PI / 4.0; // -45°

    forwardKinematics(model, data, q);

    // EE at link2 tip: +1 m along x from joint2
    SE3 tip = SE3::Identity();
    tip.translation() = Eigen::Vector3d(1.0, 0.0, 0.0);

    SE3 T_ee = data.oMi[j2] * tip;
    std::cout << "EE position (x y z): " << T_ee.translation().transpose() << '\n';
    return 0;
}
